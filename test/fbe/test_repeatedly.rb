# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/repeatedly'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestRepeatedly < Fbe::Test
  def test_simple
    $fb = Factbase.new
    $loog = Loog::NULL
    $options = Judges::Options.new
    judge = 'test'
    $global = {}
    3.times do
      Fbe.repeatedly('pmp', 'every_x_hours', judge:) do |f|
        f.foo = 42
      end
    end
    assert_equal(1, $fb.size)
    assert_equal(42, $fb.query('(always)').each.first.foo)
  end

  def test_log_uses_judge_parameter_not_global
    $judge = 'global_judge'
    fb = Factbase.new
    $fb = fb
    $global = {}
    $options = Judges::Options.new
    loog = Loog::Buffer.new
    $loog = loog
    judge = 'custom_judge'
    Fbe.repeatedly('pmp', 'every_x_hours', fb:, loog:, judge:) do |f|
      f.foo = 42
    end
    Fbe.repeatedly('pmp', 'every_x_hours', fb:, loog:, judge:) do |f|
      f.foo = 42
    end
    output = loog.to_s
    assert_includes(output, 'custom_judge')
    refute_includes(output, 'global_judge')
  end

  def test_failed_block_does_not_lock_out_next_run
    $fb = Factbase.new
    $loog = Loog::NULL
    $options = Judges::Options.new
    $global = {}
    judge = 'failing-judge'
    assert_raises(RuntimeError) do
      Fbe.repeatedly('pmp', 'every_x_hours', judge:) do |_f|
        raise(RuntimeError, 'oops')
      end
    end
    ran = false
    Fbe.repeatedly('pmp', 'every_x_hours', judge:) do |_f|
      ran = true
    end
    assert(ran)
  end

  def test_writes_the_marker_into_the_given_factbase
    $fb = Factbase.new
    $loog = Loog::NULL
    $options = Judges::Options.new
    $global = {}
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: $options, loog: Loog::NULL)
    Fbe.repeatedly('pmp', 'every_x_hours', fb:, judge: 'test') do |f|
      f.foo = 42
    end
    Time.stub(:now, Time.now + (25 * 60 * 60)) do
      Fbe.repeatedly('pmp', 'every_x_hours', fb:, judge: 'test') do |f|
        f.bar = 7
      end
    end
    assert_equal(0, $fb.size)
    assert_equal(1, fb.size)
    assert_equal(7, fb.query('(always)').each.first['bar'].first)
  end

  def test_area_with_single_quote
    fb = Factbase.new
    $fb = fb
    $loog = Loog::NULL
    $options = Judges::Options.new
    fb.txn do |fbt|
      f = fbt.insert
      f.what = 'pmp'
      f.area = "te'st"
      f.every_x_hours = 24
    end
    $global = {}
    Fbe.repeatedly("te'st", 'every_x_hours', fb:, judge: 'test') do |f|
      f.foo = 42
    end
    assert_equal(2, fb.size)
  end

  def test_judge_with_single_quote
    fb = Factbase.new
    $fb = fb
    $loog = Loog::NULL
    $options = Judges::Options.new
    fb.txn do |fbt|
      f = fbt.insert
      f.what = 'pmp'
      f.area = 'quality'
      f.every_x_hours = 24
    end
    $global = {}
    Fbe.repeatedly('quality', 'every_x_hours', fb:, judge: "te'st") do |f|
      f.foo = 42
    end
    assert_equal(2, fb.size)
  end

  def test_uses_daily_default_when_the_area_fact_omits_the_interval
    seed = Random.new_seed
    area = "качество-#{Random.new(seed).rand(1_000)}"
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: Judges::Options.new, loog: Loog::NULL)
    fb.txn do |fbt|
      f = fbt.insert
      f.what = 'pmp'
      f.area = area
      f.days = 5
    end
    Fbe.repeatedly(area, 'every_x_hours', fb:, judge: 'test', loog: Loog::NULL) do |f|
      f.foo = 42
    end
    ran = false
    Time.stub(:now, Time.now + (23 * 60 * 60)) do
      Fbe.repeatedly(area, 'every_x_hours', fb:, judge: 'test', loog: Loog::NULL) do |_f|
        ran = true
      end
    end
    refute(ran, "the judge ran again 23 hours later, while the area '#{area}' has no interval, seed is #{seed}")
  end

  def test_runs_again_after_a_day_when_the_area_fact_omits_the_interval
    seed = Random.new_seed
    area = "качество-#{Random.new(seed).rand(1_000)}"
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: Judges::Options.new, loog: Loog::NULL)
    fb.txn do |fbt|
      f = fbt.insert
      f.what = 'pmp'
      f.area = area
      f.days = 5
    end
    Fbe.repeatedly(area, 'every_x_hours', fb:, judge: 'test', loog: Loog::NULL) do |f|
      f.foo = 42
    end
    ran = false
    Time.stub(:now, Time.now + (25 * 60 * 60)) do
      Fbe.repeatedly(area, 'every_x_hours', fb:, judge: 'test', loog: Loog::NULL) do |_f|
        ran = true
      end
    end
    assert(ran, "the judge stayed idle 25 hours later, while the area '#{area}' has no interval, seed is #{seed}")
  end

  def test_prefers_the_configured_interval_over_the_daily_default
    seed = Random.new_seed
    hours = Random.new(seed).rand(2..6)
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: Judges::Options.new, loog: Loog::NULL)
    fb.txn do |fbt|
      f = fbt.insert
      f.what = 'pmp'
      f.area = 'качество'
      f.every_x_hours = hours
    end
    Fbe.repeatedly('качество', 'every_x_hours', fb:, judge: 'test', loog: Loog::NULL) do |f|
      f.foo = 42
    end
    ran = false
    Time.stub(:now, Time.now + ((hours + 1) * 60 * 60)) do
      Fbe.repeatedly('качество', 'every_x_hours', fb:, judge: 'test', loog: Loog::NULL) do |_f|
        ran = true
      end
    end
    assert(ran, "the judge stayed idle #{hours + 1} hours later, while the interval is #{hours}, seed is #{seed}")
  end
end
