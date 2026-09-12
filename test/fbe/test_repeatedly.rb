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

  def test_claims_the_marker_before_the_block_runs
    fb = Factbase.new
    $fb = fb
    $loog = Loog::NULL
    $options = Judges::Options.new
    $global = {}
    seen = nil
    Fbe.repeatedly('pmp', 'every_x_hours', fb:, judge: 'test') do |_f|
      seen = fb.query("(and (eq what 'test') (exists when))").each.to_a.size
    end
    assert_equal(
      1, seen,
      'the marker must be in place before the block runs, or a second judge starts the very same work'
    )
  end

  def test_restores_the_previous_marker_when_the_block_fails
    $fb = Factbase.new
    $loog = Loog::NULL
    $options = Judges::Options.new
    $global = {}
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: $options, loog: Loog::NULL)
    Fbe.repeatedly('pmp', 'every_x_hours', fb:, judge: 'test') { |f| f.foo = 42 }
    was = fb.query("(and (eq what 'test'))").each.first['when'].first
    Time.stub(:now, Time.now + (25 * 60 * 60)) do
      assert_raises(RuntimeError) do
        Fbe.repeatedly('pmp', 'every_x_hours', fb:, judge: 'test') { |_f| raise(RuntimeError, 'oops') }
      end
    end
    assert_equal(
      was, fb.query("(and (eq what 'test'))").each.first['when'].first,
      'a failed run must give the marker back, so the work is tried again'
    )
  end
end
