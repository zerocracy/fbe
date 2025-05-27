# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require 'time'
require_relative '../fbe'
require_relative 'fb'
require_relative 'octo'
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
#     as 'issues-iterator'
#     by '(and (eq what "issue") (gt created_at $before))'
#     repeats 5
#     quota_aware
#     over(timeout: 300) do |repository_id, issue_id|
#       process_issue(repository_id, issue_id)
#       issue_id + 1
#     end
#   end
def Fbe.iterate(fb: Fbe.fb, loog: $loog, options: $options, global: $global, &)
  raise 'The fb is nil' if fb.nil?
  raise 'The $global is not set' if global.nil?
  raise 'The $options is not set' if options.nil?
  raise 'The $loog is not set' if loog.nil?
  c = Fbe::Iterate.new(fb:, loog:, options:, global:)
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
#   iterator.as('pull-requests')
#   iterator.by('(and (eq what "pull_request") (gt number $before))')
#   iterator.repeats(10)
#   iterator.quota_aware
#   iterator.over(timeout: 600) do |repo_id, pr_number|
#     # Process pull request
#     fetch_and_store_pr(repo_id, pr_number)
#     pr_number  # Return next PR number to process
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
  def initialize(fb:, loog:, options:, global:)
    @fb = fb
    @loog = loog
    @options = options
    @global = global
    @label = nil
    @since = 0
    @query = nil
    @repeats = 1
    @quota_aware = false
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
  def quota_aware
    @quota_aware = true
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
  #   iterator.as('issue-processor')
  def as(label)
    raise 'Label is already set' unless @label.nil?
    raise 'Cannot set "label" to nil' if label.nil?
    @label = label
  end

  # Executes the iteration over all configured repositories.
  #
  # Processes each repository by executing the configured query repeatedly.
  # The query receives two parameters: $before (previous iteration's result)
  # and $repository (GitHub repository ID). The block must return an Integer
  # representing the next item to process, or the iteration will fail.
  #
  # The method tracks progress using marker facts and supports:
  # - Automatic restart when query returns nil
  # - Timeout to prevent infinite loops
  # - GitHub API quota checking (if enabled)
  # - State persistence for resuming
  #
  # @param [Float] timeout Maximum seconds to run (default: 120)
  # @yield [Integer, Integer] Repository ID and the item ID from query
  # @yieldreturn [Integer] The ID to use as "latest" marker for next iteration
  # @return [nil] Nothing is returned
  # @raise [RuntimeError] If block doesn't return an Integer
  # @example Process issues with timeout
  #   iterator.over(timeout: 300) do |repo_id, issue_id|
  #     issue = fetch_issue(repo_id, issue_id)
  #     store_issue(issue)
  #     issue_id  # Return same ID to mark as processed
  #   end
  def over(timeout: 2 * 60, &)
    raise 'Use "as" first' if @label.nil?
    raise 'Use "by" first' if @query.nil?
    seen = {}
    oct = Fbe.octo(loog: @loog, options: @options, global: @global)
    if oct.off_quota
      @loog.debug('We are off GitHub quota, cannot even start, sorry')
      return
    end
    repos = Fbe.unmask_repos(loog: @loog, options: @options, global: @global)
    restarted = []
    start = Time.now
    loop do
      if oct.off_quota
        @loog.info("We are off GitHub quota, time to stop after #{start.ago}")
        break
      end
      repos.each do |repo|
        if oct.off_quota
          @loog.debug("We are off GitHub quota, we must skip #{repo}")
          break
        end
        if Time.now - start > timeout
          $loog.info("We are doing this for #{start.ago} already, won't check #{repo}")
          next
        end
        next if restarted.include?(repo)
        seen[repo] = 0 if seen[repo].nil?
        if seen[repo] >= @repeats
          @loog.debug("We've seen too many (#{seen[repo]}) in #{repo}, let's see next one")
          next
        end
        rid = oct.repo_id_by_name(repo)
        before = @fb.query(
          "(agg (and (eq what '#{@label}') (eq where 'github') (eq repository #{rid})) (first latest))"
        ).one
        @fb.query("(and (eq what '#{@label}') (eq where 'github') (eq repository #{rid}))").delete!
        before = before.nil? ? @since : before.first
        nxt = @fb.query(@query).one(@fb, before:, repository: rid)
        after =
          if nxt.nil?
            @loog.debug("Next element after ##{before} not suggested, re-starting from ##{@since}: #{@query}")
            restarted << repo
            @since
          else
            @loog.debug("Next is ##{nxt}, starting from it...")
            yield(rid, nxt)
          end
        raise "Iterator must return an Integer, while #{after.class} returned" unless after.is_a?(Integer)
        f = @fb.insert
        f.where = 'github'
        f.repository = rid
        f.latest =
          if after.nil?
            @loog.debug("After is nil at #{repo}, setting the 'latest' to ##{nxt}")
            nxt
          else
            @loog.debug("After is ##{after} at #{repo}, setting the 'latest' to it")
            after
          end
        f.what = @label
        seen[repo] += 1
      end
      unless seen.any? { |r, v| v < @repeats && !restarted.include?(r) }
        @loog.debug("No more repos to scan (out of #{repos.size}), quitting after #{start.ago}")
        break
      end
      if restarted.size == repos.size
        @loog.debug("All #{repos.size} repos restarted, quitting after #{start.ago}")
        break
      end
      if Time.now - start > timeout
        $loog.info("We are iterating for #{start.ago} already, time to give up")
        break
      end
    end
    @loog.debug("Finished scanning #{repos.size} repos in #{start.ago}: #{seen.map { |k, v| "#{k}:#{v}" }.join(', ')}")
  end
end
