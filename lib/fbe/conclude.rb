# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require_relative '../fbe'
require_relative 'fb'
require_relative 'if_absent'
require_relative 'octo'

# Creates an instance of {Fbe::Conclude} and evals it with the block provided.
#
# @param [Factbase] fb The factbase
# @param [String] judge The name of the judge, from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @yield [Factbase::Fact] The fact
def Fbe.conclude(fb: Fbe.fb, judge: $judge, loog: $loog, options: $options, global: $global, time: Time, &)
  raise 'The fb is nil' if fb.nil?
  raise 'The $judge is not set' if judge.nil?
  raise 'The $global is not set' if global.nil?
  raise 'The $options is not set' if options.nil?
  raise 'The $loog is not set' if loog.nil?
  c = Fbe::Conclude.new(fb:, judge:, loog:, options:, global:, time:)
  c.instance_eval(&)
end

# A concluding block.
#
# You may want to use this class when you want to go through a number
# of facts in the factbase, applying certain algorithm to each of them
# and possibly creating new facts from them.
#
# For example, you want to make a new +good+ fact for every +bad+ fact found:
#
#  require 'fbe/conclude'
#  conclude do
#    on '(exist bad)'
#    follow 'when'
#    draw on |n, b|
#      n.good = 'yes!'
#    end
#  end
#
# This snippet will find all facts that have +bad+ property and then create
# new facts, letting the block in the {Fbe::Conclude#draw} deal with them.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Conclude
  # Ctor.
  #
  # @param [Factbase] fb The factbase
  # @param [String] judge The name of the judge, from the +judges+ tool
  # @param [Hash] global The hash for global caching
  # @param [Judges::Options] options The options coming from the +judges+ tool
  # @param [Loog] loog The logging facility
  # @param [Time] time The time
  def initialize(fb:, judge:, global:, options:, loog:, time: Time)
    @fb = fb
    @judge = judge
    @loog = loog
    @options = options
    @global = global
    @query = nil
    @follows = []
    @quota_aware = false
    @timeout = 60
    @time = time
  end

  # Make this block aware of GitHub API quota.
  #
  # When the quota is reached, the loop will gracefully stop to avoid
  # hitting GitHub API rate limits. This helps prevent interruptions
  # in long-running operations.
  #
  # @return [nil] Nothing is returned
  def quota_aware
    @quota_aware = true
  end

  # Make sure this block runs for less than allowed amount of seconds.
  #
  # When the quota is reached, the loop will gracefully stop to avoid.
  # This helps prevent interruptions in long-running operations.
  #
  # @param [Float] sec Seconds
  # @return [nil] Nothing is returned
  def timeout(sec)
    @timeout = sec
  end

  # Set the query that should find the facts in the factbase.
  #
  # @param [String] query The query to execute
  # @return [nil] Nothing is returned
  def on(query)
    raise 'Query is already set' unless @query.nil?
    @query = query
  end

  # Set the list of properties to copy from the facts found to new facts.
  #
  # @param [Array<String>] props List of property names
  # @return [nil] Nothing
  def follow(props)
    @follows = props.strip.split.compact
  end

  # Create new fact from every fact found by the query.
  #
  # For example, you want to conclude a +reward+ from every +win+ fact:
  #
  #  require 'fbe/conclude'
  #  conclude do
  #    on '(exist win)'
  #    follow 'win when'
  #    draw on |n, w|
  #      n.reward = 10
  #    end
  #  end
  #
  # This snippet will find all facts that have +win+ property and will create
  # new facts for all of them, passing them one by one in to the block of
  # the +draw+, where +n+ would be the new created fact and the +w+ would
  # be the fact found.
  #
  # @yield [Array<Factbase::Fact,Factbase::Fact>] New fact and seen fact
  # @return [Integer] The count of the facts processed
  def draw(&)
    roll do |fbt, a|
      n = fbt.insert
      fill(n, a, &)
      n
    end
  end

  # Take every fact, allowing the given block to process it.
  #
  # For example, you want to add +when+ property to every fact:
  #
  #  require 'fbe/conclude'
  #  conclude do
  #    on '(always)'
  #    consider on |f|
  #      f.when = Time.new
  #    end
  #  end
  #
  # @yield [Factbase::Fact] The next fact found by the query
  # @return [Integer] The count of the facts processed
  def consider(&)
    roll do |_fbt, a|
      yield a
      nil
    end
  end

  private

  # Executes a query and processes each matching fact.
  #
  # This internal method handles fetching facts from the factbase,
  # monitoring quotas and timeouts, and processing each fact through
  # the provided block.
  #
  # @yield [Factbase::Transaction, Factbase::Fact] Transaction and the matching fact
  # @return [Integer] The count of facts processed
  # @example
  #   # Inside the Fbe::Conclude class
  #   def example_method
  #     roll do |fbt, fact|
  #       # Process the fact
  #       new_fact = fbt.insert
  #       # Return the new fact
  #       new_fact
  #     end
  #   end
  def roll(&)
    passed = 0
    start = @time.now
    oct = Fbe.octo(loog: @loog, options: @options, global: @global)
    @fb.query(@query).each do |a|
      if @quota_aware && oct.off_quota?
        @loog.debug('We ran out of GitHub quota, must stop here')
        break
      end
      now = @time.now
      if now > start + @timeout
        @loog.debug("We've spent more than #{start.ago}, must stop here")
        break
      end
      @fb.txn do |fbt|
        n = yield fbt, a
        @loog.info("#{n.what}: #{n.details}") unless n.nil?
      end
      passed += 1
    end
    @loog.debug("Found and processed #{passed} facts by: #{@query}")
    passed
  end

  # Populates a new fact based on a previous fact and a processing block.
  #
  # This internal method copies specified properties from the previous fact,
  # calls the provided block for custom processing, and sets metadata
  # on the new fact.
  #
  # @param [Factbase::Fact] fact The fact to populate
  # @param [Factbase::Fact] prev The previous fact to copy from
  # @yield [Factbase::Fact, Factbase::Fact] New fact and the previous fact
  # @return [nil]
  # @example
  #   # Inside the Fbe::Conclude class
  #   def example_method
  #     @fb.txn do |fbt|
  #       new_fact = fbt.insert
  #       fill(new_fact, existing_fact) do |n, prev|
  #         n.some_property = "new value"
  #         "Operation completed"  # This becomes fact.details
  #       end
  #     end
  #   end
  def fill(fact, prev)
    @follows.each do |follow|
      v = prev.send(follow)
      fact.send(:"#{follow}=", v)
    end
    r = yield fact, prev
    return unless r.is_a?(String)
    fact.details = r
    fact.what = @judge
  end
end
