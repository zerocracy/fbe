# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require 'time'
require_relative '../fbe'
require_relative 'fb'
require_relative 'octo'
require_relative 'unmask_repos'

# Creates an instance of {Fbe::Iterate} and evals it with the block provided.
#
# @param [Factbase] fb The global factbase provided by the +judges+ tool
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Loog] loog The logging facility
# @yield [Factbase::Fact] The fact
def Fbe.iterate(fb: Fbe.fb, loog: $loog, options: $options, global: $global, &)
  c = Fbe::Iterate.new(fb:, loog:, options:, global:)
  c.instance_eval(&)
end

# An iterator.
#
# Here, you go through all repositories defined by the +repositories+ option
# in the +$options+, trying to run the provided query for each of them. If the
# query returns an integer that is different from the previously seen, the
# function keeps repeating the cycle. Otherwise, it will restart from the
# beginning.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Iterate
  # Ctor.
  #
  # @param [Factbase] fb The factbase
  # @param [Loog] loog The logging facility
  # @param [Judges::Options] options The options coming from the +judges+ tool
  # @param [Hash] global The hash for global caching
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

  # Make this block aware of GitHub API quota.
  #
  # When the quota is reached, the loop will gracefully stop.
  #
  # @return [nil] Nothing
  def quota_aware
    @quota_aware = true
  end

  # Sets the total counter of repeats to make.
  #
  # @param [Integer] repeats The total count of them
  # @return [nil] Nothing
  def repeats(repeats)
    raise 'Cannot set "repeats" to nil' if repeats.nil?
    raise 'The "repeats" must be a positive integer' unless repeats.positive?
    @repeats = repeats
  end

  # Sets the query to run.
  #
  # @param [String] query The query
  # @return [nil] Nothing
  def by(query)
    raise 'Query is already set' unless @query.nil?
    raise 'Cannot set query to nil' if query.nil?
    @query = query
  end

  # Sets the label to use in the "marker" fact.
  #
  # @param [String] label The label
  # @return [nil] Nothing
  def as(label)
    raise 'Label is already set' unless @label.nil?
    raise 'Cannot set "label" to nil' if label.nil?
    @label = label
  end

  # It makes a number of repeats of going through all repositories
  # provided by the +repositories+ configuration option. In each "repeat"
  # it yields the repository ID and a number that is retrieved by the
  # +query+. The query is supplied with two parameter:
  # +$before+ the value from the previous repeat and +$repository+ (GitHub repo ID).
  #
  # @param [Float] timeout How many seconds to spend as a maximum
  # @yield [Array<Integer, Integer>] Repository ID and the next number to be considered
  # @return [nil] Nothing
  def over(timeout: 2 * 60, &)
    raise 'Use "as" first' if @label.nil?
    raise 'Use "by" first' if @query.nil?
    seen = {}
    oct = Fbe.octo(loog: @loog, options: @options, global: @global)
    repos = Fbe.unmask_repos(loog: @loog, options: @options, global: @global)
    restarted = []
    start = Time.now
    loop do
      repos.each do |repo|
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
        nxt = @fb.query(@query).one(before:, repository: rid)
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
        if oct.off_quota
          @loog.debug('We are off GitHub quota, time to stop')
          break
        end
      end
      if oct.off_quota
        @loog.info("We are off GitHub quota, time to stop after #{start.ago}")
        break
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
