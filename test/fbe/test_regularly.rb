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
    fact = fb.query("(eq what '#{judge}')").each.first
    refute_nil(fact)
    refute_nil(fact.since)
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

  def test_numeric_string_configuration
    [28, '28', 28.5, '28.5'].each do |days|
      fb = Factbase.new
      pmp = fb.insert
      pmp.what = 'pmp'
      pmp.area = 'quality'
      pmp.interval = '3'
      pmp.days = days
      2.times do
        Fbe.regularly('quality', 'interval', 'days', fb:, loog: Loog::NULL, judge: 'test') do |fact|
          fact.result = 42
        end
      end
      facts = fb.query('(eq what "test")').each.to_a
      assert_equal(1, facts.size)
      assert_in_delta(Float(days) * 86_400, facts.first.when - facts.first.since, 1)
    end
  end

  def test_rejects_invalid_configuration_before_callback
    invalid = %w[invalid 1e999]
    %w[interval days].each do |property|
      invalid.each do |value|
        fb = Factbase.new
        pmp = fb.insert
        pmp.what = 'pmp'
        pmp.area = 'quality'
        pmp.public_send(:"#{property}=", value)
        before = fb.export
        called = false
        assert_raises(Fbe::Error) do
          Fbe.regularly('quality', 'interval', 'days', fb:, loog: Loog::NULL, judge: 'test') do |_fact|
            called = true
          end
        end
        refute(called)
        assert_equal(before, fb.export)
      end
    end
  end
end
