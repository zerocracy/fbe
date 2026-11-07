# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require_relative '../../lib/fbe/regularly'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestRegularly < Fbe::Test
  def test_simple
    fb = Factbase.new
    loog = Loog::NULL
    judge = 'test'
    2.times do
      Fbe.regularly('pmp', 'interval', 'days', fb:, loog:, judge:) do |f|
        f.foo = 42
      end
    end
    assert_equal(1, fb.size)
  end

  def test_waits_for_a_fractional_interval
    assert_equal(0, regular_runs(0.5, 3600), 'One hour must be too early for an interval of half a day')
  end

  def test_runs_after_a_fractional_interval
    assert_equal(1, regular_runs(0.5, 13 * 3600), 'Thirteen hours must be enough for an interval of half a day')
  end

  def test_rolls_back
    fb = Factbase.new
    loog = Loog::NULL
    judge = 'test'
    Fbe.regularly('pmp', 'interval', 'days', fb:, loog:, judge:) do |_f|
      raise(Factbase::Rollback)
    end
    assert_equal(0, fb.size)
  end

  def test_log_uses_judge_parameter_not_global
    $judge = 'global_judge'
    fb = Factbase.new
    loog = Loog::Buffer.new
    judge = 'custom_judge'
    Fbe.regularly('pmp', 'interval', 'days', fb:, loog:, judge:) do |f|
      f.foo = 42
    end
    Fbe.regularly('pmp', 'interval', 'days', fb:, loog:, judge:) do |f|
      f.foo = 42
    end
    output = loog.to_s
    assert_includes(output, 'custom_judge')
    refute_includes(output, 'global_judge')
  end

  def test_uses_default_since_days_when_pmp_lacks_property
    fb = Factbase.new
    fb.txn do |fbt|
      f = fbt.insert
      f.what = 'pmp'
      f.area = 'quality'
      f.interval = 3
    end
    loog = Loog::NULL
    judge = 'test'
    Fbe.regularly('quality', 'interval', 'days', fb:, loog:, judge:) do |f|
      f.foo = 42
    end
    assert_equal(2, fb.size)
    fact = fb.query("(and (eq what 'regularly') (eq judge '#{judge}'))").each.first
    refute_nil(fact)
    refute_nil(fact.since)
  end

  def test_does_not_mistake_a_conclusion_fact_for_its_own_marker
    fb = Factbase.new
    judge = 'my-judge'
    fb.txn do |fbt|
      f = fbt.insert
      f.what = judge
      f.details = 'Something long enough to satisfy the rules of the game'
      f.when = Time.now
    end
    ran = false
    Fbe.regularly('pmp', 'interval', 'days', fb:, loog: Loog::NULL, judge:) do |f|
      ran = true
      f.foo = 42
    end
    assert(ran, 'Fbe.regularly should have run: a conclusion fact is not its own marker')
  end

  def test_area_with_single_quote
    fb = Factbase.new
    fb.txn do |fbt|
      f = fbt.insert
      f.what = 'pmp'
      f.area = "te'st"
      f.interval = 3
    end
    loog = Loog::NULL
    Fbe.regularly("te'st", 'interval', 'days', fb:, loog:, judge: 'test') do |f|
      f.foo = 42
    end
    assert_equal(2, fb.size)
  end

  def test_judge_with_single_quote
    fb = Factbase.new
    fb.txn do |fbt|
      f = fbt.insert
      f.what = 'pmp'
      f.area = 'quality'
      f.interval = 3
    end
    loog = Loog::NULL
    Fbe.regularly('quality', 'interval', 'days', fb:, loog:, judge: "te'st") do |f|
      f.foo = 42
    end
    assert_equal(2, fb.size)
  end

  private

  def regular_runs(every, age)
    fb = Factbase.new
    pm = fb.insert
    pm.what = 'pmp'
    pm.area = 'a'
    pm.every = every
    m = fb.insert
    m.what = 'regularly'
    m.judge = 'jj'
    m.when = Time.now - age
    runs = 0
    Fbe.regularly('a', 'every', fb:, judge: 'jj', loog: Loog::NULL) { runs += 1 }
    runs
  end
end
