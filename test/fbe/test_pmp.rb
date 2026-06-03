# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/pmp'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestPmp < Fbe::Test
  def test_defaults
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    f = Fbe.fb(loog: Loog::NULL).insert
    f.what = 'pmp'
    f.area = 'hr'
    f.days_to_reward = 55
    $loog = Loog::NULL
    assert_equal(55, Fbe.pmp(loog: Loog::NULL).hr.days_to_reward)
  end

  def test_some_defaults
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    assert_equal(14, Fbe.pmp(loog: Loog::NULL).hr.days_to_reward)
    assert_equal(56, Fbe.pmp(loog: Loog::NULL).hr.days_of_running_score)
    assert_equal(10, Fbe.pmp(loog: Loog::NULL).integration.eva_interval)
    refute(Fbe.pmp(loog: Loog::NULL).communications.stealth)
  end

  def test_converts_to_correct_type
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    f = Fbe.fb(loog: Loog::NULL).insert
    f.what = 'pmp'
    f.area = 'hr'
    f.days_to_reward = 88.5
    $loog = Loog::NULL
    assert_equal(88, Fbe.pmp(loog: Loog::NULL).hr.days_to_reward)
  end

  def test_reads_meta_info
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    v = Fbe.pmp(loog: Loog::NULL).hr.days_to_reward
    assert(v.default)
    assert(v.type)
    assert(v.memo)
  end

  def test_reads_other_props
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    f = Fbe.fb(loog: Loog::NULL).insert
    f.what = 'pmp'
    f.area = 'hr'
    f.something_else = 42
    $loog = Loog::NULL
    assert_equal(42, Fbe.pmp(loog: Loog::NULL).hr.something_else)
  end

  def test_reads_false_boolean
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    f = Fbe.fb(loog: Loog::NULL).insert
    f.what = 'pmp'
    f.area = 'communications'
    f.stealth = 'false'
    $loog = Loog::NULL
    refute(Fbe.pmp(loog: Loog::NULL).communications.stealth)
    refute(Fbe.pmp(loog: Loog::NULL).communications.stealth.value)
  end

  def test_reads_true_boolean
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    f = Fbe.fb(loog: Loog::NULL).insert
    f.what = 'pmp'
    f.area = 'communications'
    f.stealth = 'true'
    $loog = Loog::NULL
    assert(Fbe.pmp(loog: Loog::NULL).communications.stealth)
    assert(Fbe.pmp(loog: Loog::NULL).communications.stealth.value)
  end

  def test_regression_bool_true_default
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    cust = '<pmp><area name="t"><p><name>x</name>' \
           '<default>true</default><type>bool</type><memo>x</memo></p></area></pmp>'
    orig = File.method(:read)
    File.stub(:read, ->(p, **k) { p.end_with?('pmp.xml') ? cust : orig.call(p, **k) }) do
      assert(Fbe.pmp(loog: Loog::NULL).t.f)
    end
  end

  def test_custom_area
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    fb = Fbe.fb(fb: Factbase.new, global: $global, options: $options, loog: $loog)
    f = fb.insert
    f.what = 'pmp'
    f.area = 'custom'
    f.my_prop = 42
    assert_equal(42, Fbe.pmp(fb:, loog: Loog::NULL).custom.my_prop)
  end

  def test_custom_area_without_fact
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    fb = Factbase.new
    v = Fbe.pmp(fb:, loog: Loog::NULL).custom.my_prop
    assert_nil(v.value)
  end

  def test_custom_area_properties
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    $fb = Factbase.new
    f = $fb.insert
    f.what = 'pmp'
    f.area = 'custom'
    f.prop_a = 1
    f.prop_b = 2
    props = Fbe.pmp(loog: Loog::NULL).custom.properties
    assert_includes(props, 'prop_a')
    assert_includes(props, 'prop_b')
  end
end
