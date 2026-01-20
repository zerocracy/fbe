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
  end

  def test_fail_on_wrong_area
    $global = {}
    $loog = Loog::NULL
    assert_raises(StandardError) { Fbe.pmp(Factbase.new, loog: Loog::NULL).something }
  end
end
