# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'judges/options'
require 'loog'
require 'factbase'
require_relative '../test__helper'
require_relative '../../lib/fbe/pmp'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestPmp < Minitest::Test
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

  def test_fail_on_wrong_area
    $global = {}
    $loog = Loog::NULL
    assert_raises(StandardError) { Fbe.pmp(Factbase.new, loog: Loog::NULL).something }
  end
end
