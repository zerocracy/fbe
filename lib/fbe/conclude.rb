# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require_relative '../fbe'
require_relative 'fb'
require_relative 'if_absent'
require_relative 'octo'
require_relative 'over'

# Creates an instance of {Fbe::Conclude} and evals it with the block provided.
#
# @param [Factbase] fb The factbase
# @param [String] judge The name of the judge, from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @param [Time] epoch When the entire update started
# @param [Time] kickoff When the particular judge started
# @param [Integer] slot Seconds a single iteration may need; the loop stops
#   before starting a new one when less than this many seconds remain in the
#   timeout (or lifetime) budget
# @yield [Factbase::Fact] The fact
def Fbe.conclude(
  fb: Fbe.fb, judge: $judge, loog: $loog, options: $options, global: $global,
  epoch: $epoch || Time.now, kickoff: $kickoff || Time.now, slot: 1, &
)
  raise(Fbe::Error, 'The fb is nil') if fb.nil?
  raise(Fbe::Error, 'The $judge is not set') if judge.nil?
  raise(Fbe::Error, 'The $global is not set') if global.nil?
  raise(Fbe::Error, 'The $options is not set') if options.nil?
  raise(Fbe::Error, 'The $loog is not set') if loog.nil?
  c = Fbe::Conclude.new(fb:, judge:, loog:, options:, global:, epoch:, kickoff:, slot:)
  c.instance_eval(&)
end

# A concluding block.
#
# You may want to use this class when you want to go through a number
# of facts in the factbase, applying a certain algorithm to each of them
# and possibly creating new facts from them.
#
# For example, you want to make a new +good+ fact for every +bad+ fact found:
#
#  require 'fbe/conclude'
#  conclude do
#    on '(exists bad)'
#    follow 'when'
#    draw do |n, b|
#      n.good = 'yes!'
#    end
#  end
#
# This snippet will find all facts that have +bad+ property and then create
# new facts, letting the block in the {Fbe::Conclude#draw} deal with them.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class Fbe::Conclude
  # Ctor.
  #
  # @param [Factbase] fb The factbase
  # @param [String] judge The name of the judge, from the +judges+ tool
  # @param [Hash] global The hash for global caching
  # @param [Judges::Options] options The options coming from the +judges+ tool
  # @param [Loog] loog The logging facility
  # @param [Time] epoch When the entire update started
  # @param [Time] kickoff When the particular judge started
  # @param [Integer] slot Seconds a single iteration may need
  def initialize(fb:, judge:, global:, options:, loog:, epoch:, kickoff:, slot: 1)
    @fb = fb
    @judge = judge
    @loog = loog
    @options = options
    @global = global
    @epoch = epoch
    @kickoff = kickoff
    @slot = slot
    @query = nil
    @follows = []
    @lifetime = true
    @timeout = true
    @quota = true
  end

  # Make this block not aware of GitHub API quota.
  #
  # When the quota is reached, the loop will NOT gracefully stop to avoid
  # hitting GitHub API rate limits.
  #
  # @return [nil] Nothing is returned
  def quota_unaware
    @quota = false
  end

  # Make this block NOT aware of lifetime limitations.
  #
  # When the lifetime is over, the loop will NOT gracefully stop.
  #
  # @return [nil] Nothing is returned
  def lifetime_unaware
    @lifetime = false
  end

  # Make this block NOT aware of timeout limitations.
  #
  # When the timeout is over, the loop will NOT gracefully stop.
  #
  # @return [nil] Nothing is returned
  def timeout_unaware
    @timeout = false
  end

  # Set the query that should find the facts in the factbase.
  #
  # @param [String] query The query to execute
  # @return [nil] Nothing is returned
  def on(query)
    raise(Fbe::Error, 'Query is already set') unless @query.nil?
    @query = query
  end

  # Set the list of properties to copy from the facts found to new facts.
  #
  # @param [Array<String>] props List of property names
  # @return [nil] Nothing
  def follow(props)
    raise(Fbe::Error, 'Follow is already set') unless @follows.empty?
    @follows = props.strip.split.compact
  end

  # Create new fact from every fact found by the query.
  #
  # For example, you want to conclude a +reward+ from every +win+ fact:
  #
  #  require 'fbe/conclude'
  #  conclude do
  #    on '(exists win)'
  #    follow 'win when'
  #    draw do |n, w|
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
  #    consider do |f|
  #      f.when = Time.new
  #    end
  #  end
  #
  # @yield [Factbase::Fact] The next fact found by the query
  # @return [Integer] The count of the facts processed
  def consider(&)
    roll do |_fbt, a|
      yield(a)
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
  # Besides the {Fbe.over?} check (which stops once the elapsed time crosses
  # the fixed 90% margin of the timeout), the loop also reserves one +@slot+
  # up front: it stops before starting a new iteration when fewer than +@slot+
  # seconds remain in the timeout (or lifetime) budget. This prevents a slow
  # single step from starting late and overrunning the hard timeout enforced
  # by the +judges+ gem.
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
    return 0 if Fbe.over?(
      global: @global, options: @options, loog: @loog, epoch: @epoch, kickoff: @kickoff,
      quota_aware: @quota, lifetime_aware: @lifetime, timeout_aware: @timeout
    )
    passed = 0
    @fb.query(@query).each do |a|
      break if Fbe.over?(
        global: @global, options: @options, loog: @loog, epoch: @epoch, kickoff: @kickoff,
        quota_aware: @quota, lifetime_aware: @lifetime, timeout_aware: @timeout
      )
      if @timeout && @options.timeout && @options.timeout - (Time.now - @kickoff) < @slot
        @loog.info("Less than #{@slot}s left before the timeout, must stop here")
        break
      end
      if @lifetime && @options.lifetime && @options.lifetime - (Time.now - @epoch) < @slot
        @loog.info("Less than #{@slot}s left before the lifetime ends, must stop here")
        break
      end
      @fb.txn do |fbt|
        n = yield(fbt, a)
        unless n.nil?
          props = n.all_properties
          if props.include?('what') && props.include?('details')
            @loog.info("#{n.what}: #{n.details}")
          end
        end
      end
      passed += 1
    end
    @loog.debug("Found and processed #{passed} facts by: #{@query}")
    passed
  rescue Fbe::OffQuota => e
    @loog.info(e.message)
    passed
  end

  # Populates a new fact based on a previous fact and a processing block.
  #
  # This internal method copies specified properties from the previous fact,
  # calls the provided block for custom processing, and sets metadata
  # on the new fact.
  #
  # A property that is absent on the previous fact is skipped (its "[]"
  # accessor returns nil). Factbase's "(as new old)" rewrite is only visible
  # through method access (prev.new), while "[]" returns the raw stored value
  # (see #595); when such a rewrite is in effect the method accessor returns
  # the rewritten value, so we honor it. All values are still copied for
  # genuinely multi-valued properties (see #520).
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
      key = follow.to_s
      values = prev[key]
      next if values.nil?
      rewritten = prev.public_send(follow)
      values = [rewritten] unless values.first == rewritten
      values.each do |v|
        fact.public_send(:"#{follow}=", v)
      end
    end
    r = yield(fact, prev)
    return unless r.is_a?(String)
    fact.details = r
    fact.what = @judge
  end
end
