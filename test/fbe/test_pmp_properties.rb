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
class TestPmpProperties < Fbe::Test
  def test_lists_stored_and_declared_properties
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    f = Fbe.fb(loog: Loog::NULL).insert
    f.what = 'pmp'
    f.area = 'hr'
    f.bug_report_was_rewarded = '(award (give 12 "x"))'
    props = Fbe.pmp(loog: Loog::NULL).hr.properties
    assert_includes(props, 'bug_report_was_rewarded')
    assert_includes(props, 'anger')
  end

  def test_hides_the_internals_of_a_custom_area
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    f = Fbe.fb(loog: Loog::NULL).insert
    f.what = 'pmp'
    f.area = 'mycustom'
    f.my_prop = 7
    assert_equal(['my_prop'], Fbe.pmp(loog: Loog::NULL).mycustom.properties)
  end
end
