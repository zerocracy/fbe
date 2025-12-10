# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/pmp'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
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

  def test_fail_on_wrong_area
    $global = {}
    $loog = Loog::NULL
    assert_raises(StandardError) { Fbe.pmp(Factbase.new, loog: Loog::NULL).something }
  end
end
