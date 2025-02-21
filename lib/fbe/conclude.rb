# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'
require_relative 'octo'
require_relative 'if_absent'

# Creates an instance of {Fbe::Conclude} and evals it with the block provided.
#
# @param [Factbase] fb The factbase
# @param [String] judge The name of the judge, from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @yield [Factbase::Fact] The fact
def Fbe.conclude(fb: Fbe.fb, judge: $judge, loog: $loog, options: $options, global: $global, &)
  c = Fbe::Conclude.new(fb:, judge:, loog:, options:, global:)
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
  def initialize(fb:, judge:, global:, options:, loog:)
    @fb = fb
    @judge = judge
    @loog = loog
    @options = options
    @global = global
    @query = nil
    @follows = []
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

  # Set the query that should find the facts in the factbase.
  #
  # @param [String] query The query
  # @return [nil] Nothing
  def on(query)
    raise 'Query is already set' unless @query.nil?
    @query = query
  end

  # Set the list of properties to copy from the facts found to new facts.
  #
  # @param [Arra<String>] props List of property names
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

  # @yield [Factbase::Fact] The next fact found by the query
  # @return [Integer] The count of the facts seen
  def roll(&)
    passed = 0
    catch :stop do
      @fb.txn do |fbt|
        fbt.query(@query).each do |a|
          throw :stop if @quota_aware && Fbe.octo(loog: @loog, options: @options, global: @global).off_quota
          n = yield fbt, a
          @loog.info("#{n.what}: #{n.details}") unless n.nil?
          passed += 1
        end
      end
    end
    @loog.debug("Found and processed #{passed} facts by: #{@query}")
    passed
  end

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
