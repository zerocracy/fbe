# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'joined'
require 'tago'
require 'time'
require_relative '../fbe'
require_relative 'fb'
require_relative 'if_absent'
require_relative 'octo'
require_relative 'over'
require_relative 'overwrite'
require_relative 'unmask_repos'

# Creates an instance of {Fbe::Iterate} and evaluates it with the provided block.
#
# This is a convenience method that creates an iterator instance and evaluates
# the DSL block within its context. The iterator processes repositories defined
# in options.repositories, executing queries and managing state for each.
#
# @param [Factbase] fb The global factbase provided by the +judges+ tool (defaults to Fbe.fb)
# @param [Judges::Options] options The options from judges tool (uses $options global)
# @param [Hash] global The hash for global caching (uses $global)
# @param [Loog] loog The logging facility (uses $loog global)
# @yield Block containing DSL methods (as, by, over, etc.) to configure iteration
# @return [Object] Result of the block evaluation
# @raise [RuntimeError] If required globals are not set
# @example Iterate through repositories processing issues
#   Fbe.iterate do
#     as 'issues_iterator'
#     by '(and (eq what "issue") (gt created_at $before))'
#     repeats 5
#     quota_aware
#     over do |repository_id, issue_id|
#       process_issue(repository_id, issue_id)
#       issue_id + 1
#     end
#   end
def Fbe.iterate(
  fb: Fbe.fb, loog: $loog, options: $options, global: $global,
  epoch: $epoch || Time.now, kickoff: $kickoff || Time.now, &
)
  raise 'The fb is nil' if fb.nil?
  raise 'The $global is not set' if global.nil?
  raise 'The $options is not set' if options.nil?
  raise 'The $loog is not set' if loog.nil?
  c = Fbe::Iterate.new(fb:, loog:, options:, global:, epoch:, kickoff:)
  c.instance_eval(&)
end

# Repository iterator with stateful query execution.
#
# This class provides a DSL for iterating through repositories and executing
# queries while maintaining state between iterations. It tracks progress using
# "marker" facts in the factbase and supports features like:
#
# - Stateful iteration with automatic restart capability
# - GitHub API quota awareness to prevent rate limit issues
# - Configurable repeat counts per repository
# - Timeout controls for long-running operations
#
# The iterator executes a query for each repository, passing the previous
# result as context. If the query returns nil, it restarts from the beginning
# for that repository. Progress is persisted in the factbase to support
# resuming after interruptions.
#
# @example Processing pull requests with state management
#   iterator = Fbe::Iterate.new(fb: fb, loog: loog, options: options, global: global)
#   iterator.as('pull_requests')
#   iterator.by('(and (eq what "pull_request") (gt number $before))')
#   iterator.repeats(10)
#   iterator.quota_aware
#   iterator.over(timeout: 600) do |repo_id, pr_number|
#     # Process pull request
#     fetch_and_store_pr(repo_id, pr_number)
#     pr_number + 1  # Return next PR number to process
#   end
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Iterate
  # Creates a new iterator instance.
  #
  # @param [Factbase] fb The factbase for storing iteration state
  # @param [Loog] loog The logging facility for debug output
  # @param [Judges::Options] options The options containing repository configuration
  # @param [Hash] global The hash for global caching of API responses
  def initialize(fb:, loog:, options:, global:, epoch:, kickoff:)
    @fb = fb
    @loog = loog
    @options = options
    @global = global
    @epoch = epoch
    @kickoff = kickoff
    @label = nil
    @since = 0
    @query = nil
    @sort_by = nil
    @repeats = 1
    @quota_aware = true
    @lifetime_aware = true
    @timeout_aware = true
  end

  # Makes the iterator aware of GitHub API quota limits.
  #
  # When enabled, the iterator will check quota status before processing
  # each repository and gracefully stop when the quota is exhausted.
  # This prevents API errors and allows for resuming later.
  #
  # @return [nil] Nothing is returned
  # @example Enable quota awareness
  #   iterator.quota_aware
  #   iterator.over { |repo, item| ... }  # Will stop if quota exhausted
  def quota_unaware
    @quota_aware = false
  end

  # Makes the iterator aware of lifetime limits.
  #
  # @return [nil] Nothing is returned
  def lifetime_unaware
    @lifetime_aware = false
  end

  # Makes the iterator aware of timeout limits.
  #
  # @return [nil] Nothing is returned
  def timeout_unaware
    @timeout_aware = false
  end

  # Sets the maximum number of iterations per repository.
  #
  # Controls how many times the query will be executed for each repository
  # before moving to the next one. Useful for limiting processing scope.
  #
  # @param [Integer] repeats The maximum iterations per repository
  # @return [nil] Nothing is returned
  # @raise [RuntimeError] If repeats is nil or not positive
  # @example Process up to 100 items per repository
  #   iterator.repeats(100)
  def repeats(repeats)
    raise 'Cannot set "repeats" to nil' if repeats.nil?
    raise 'The "repeats" must be a positive integer' unless repeats.positive?
    @repeats = repeats
  end

  # Sets the query to execute for each iteration.
  #
  # The query can use two special variables:
  # - $before: The value from the previous iteration (or initial value)
  # - $repository: The current repository ID
  #
  # @param [String] query The Factbase query to execute
  # @return [nil] Nothing is returned
  # @raise [RuntimeError] If query is already set or nil
  # @example Query for issues after a certain ID
  #   iterator.by('(and (eq what "issue") (gt id $before) (eq repo $repository))')
  def by(query)
    raise 'Query is already set' unless @query.nil?
    raise 'Cannot set query to nil' if query.nil?
    @query = query
  end

  # Sets the field to sort results by in ascending order.
  #
  # When set, all matching results will be fetched, sorted by the specified
  # field, and iterated in order. This executes the query once per repository
  # instead of calling one() repeatedly.
  #
  # @param [String] prop The fact attribute to sort by
  # @return [nil] Nothing is returned
  # @raise [RuntimeError] If prop is nil, already set, or not a valid field name
  # @example Sort issues by number
  #   iterator.sort_by('issue')
  def sort_by(prop)
    raise 'Sort field is already set' unless @sort_by.nil?
    raise 'Cannot set sort field to nil' if prop.nil?
    raise 'Sort field must be a String' unless prop.is_a?(String)
    @sort_by = prop
  end

  # Sets the label for tracking iteration state.
  #
  # The label is used to create marker facts in the factbase that track
  # the last processed item for each repository. This enables resuming
  # iteration after interruptions.
  #
  # @param [String] label Unique identifier for this iteration type
  # @return [nil] Nothing is returned
  # @raise [RuntimeError] If label is already set or nil
  # @example Set label for issue processing
  #   iterator.as('issue_processor')
  def as(label)
    raise 'Label is already set' unless @label.nil?
    raise 'Cannot set "label" to nil' if label.nil?
    raise "Wrong label format '#{label}', use [_a-z][a-zA-Z0-9_]*" unless label.match?(/\A[_a-z][a-zA-Z0-9_]*\z/)
    @label = label
  end

  # Executes the iteration over all configured repositories.
  #
  # For each repository, retrieves the last processed value (or uses the initial
  # value from +since+) and executes the configured query with it. The query
  # receives two parameters: $before (the last processed value) and $repository
  # (GitHub repository ID).
  #
  # When the query returns a non-nil result, the block is called with the
  # repository ID and query result. The block must return an Integer that will
  # be stored as the new "latest" value for the next iteration.
  #
  # When the query returns nil, the iteration for that repository restarts
  # from the initial value (set by +since+), and the block is NOT called.
  #
  # The method tracks progress using marker facts and supports:
  # - Automatic restart when query returns nil
  # - Timeout to prevent infinite loops
  # - GitHub API quota checking (if enabled)
  # - State persistence for resuming after interruptions
  #
  # Processing flow for each repository:
  # 1. Read the "latest" value from factbase (or use +since+ if not found)
  # 2. Execute the query with $before=latest and $repository=repo_id
  # 3. If query returns nil: restart from +since+ value, skip to next repo
  # 4. If query returns a value: call the block with (repo_id, query_result)
  # 5. Store the block's return value as the new "latest" for next iteration
  #
  # @yield [Integer, Object] Repository ID and the result from query execution
  # @yieldreturn [Integer] The value to store as "latest" for next iteration
  # @return [nil] Nothing is returned
  # @raise [RuntimeError] If block doesn't return an Integer
  # @example Process issues incrementally
  #   iterator.over do |repo_id, issue_number|
  #     fetch_and_process_issue(repo_id, issue_number)
  #     issue_number + 1  # Return next issue number to process
  #   end
  def over
    raise 'Use "as" first' if @label.nil?
    raise 'Use "by" first' if @query.nil?
    seen = {}
    oct = Fbe.octo(loog: @loog, options: @options, global: @global)
    if oct.off_quota?
      @loog.info('We are off GitHub quota, cannot even start, sorry')
      return
    end
    repos = Fbe.unmask_repos(
      loog: @loog, options: @options, global: @global, quota_aware: @quota_aware
    ).map { |n| oct.repo_id_by_name(n) }
    started = Time.now
    restarted = []
    before =
      repos.to_h do |repo|
        [
          repo,
          @fb.query(
            "(agg (and
              (eq what 'iterate')
              (eq where 'github')
              (eq repository #{repo}))
            (first #{@label}))"
          ).one&.first || @since
        ]
      end
    starts = before.dup
    values = {}
    loop do
      if Fbe.over?(
        global: @global, options: @options, loog: @loog, epoch: @epoch, kickoff: @kickoff,
        quota_aware: @quota_aware, lifetime_aware: @lifetime_aware, timeout_aware: @timeout_aware
      )
        @loog.info("Time to stop after #{started.ago}")
        break
      end
      repos.each do |repo|
        if Fbe.over?(
          global: @global, options: @options, loog: @loog, epoch: @epoch, kickoff: @kickoff,
          quota_aware: @quota_aware, lifetime_aware: @lifetime_aware, timeout_aware: @timeout_aware
        )
          @loog.info("Won't check repository ##{repo}")
          break
        end
        next if restarted.include?(repo)
        seen[repo] = 0 if seen[repo].nil?
        if seen[repo] >= @repeats
          @loog.debug("We've seen too many (#{seen[repo]}) in #{repo}, let's see next one")
          next
        end
        nxt =
          if @sort_by
            values[repo] ||= @fb.query(@query).each(
              @fb, before: before[repo], repository: repo
            ).map { _1[@sort_by]&.first }.compact.sort.each
            begin
              values[repo].next
            rescue StopIteration
              nil
            end
          else
            @fb.query(@query).one(@fb, before: before[repo], repository: repo)
          end
        before[repo] =
          if nxt.nil?
            @loog.debug("Next element after ##{before[repo]} not suggested, re-starting from ##{@since}: #{@query}")
            restarted << repo
            values.delete(repo) if @sort_by
            @since
          else
            @loog.debug("Next is ##{nxt}, starting from it")
            yield(repo, nxt)
          end
        unless before[repo].is_a?(Integer)
          raise "Iterator must return an Integer, but #{before[repo].class} was returned"
        end
        seen[repo] += 1
      end
      unless seen.any? { |r, v| v < @repeats && !restarted.include?(r) }
        @loog.debug("No more repos to scan (out of #{repos.size}), quitting after #{@kickoff.ago}")
        break
      end
      if restarted.size == repos.size
        @loog.debug("All #{repos.size} repos restarted, quitting after #{@kickoff.ago}")
        break
      end
    end
    repos.each do |repo|
      next if before[repo] == starts[repo]
      f =
        Fbe.if_absent(fb: @fb, always: true) do |n|
          n.what = 'iterate'
          n.where = 'github'
          n.repository = repo
        end
      Fbe.overwrite(f, @label, before[repo], fb: @fb)
    end
    @loog.debug("Finished scanning #{repos.size} repos in #{@kickoff.ago}: #{seen.map { |k, v| "#{k}:#{v}" }.joined}")
  end
end
