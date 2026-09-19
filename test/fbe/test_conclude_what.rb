# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/conclude'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestConcludeWhat < Fbe::Test
  def test_marks_the_fact_even_without_details
    $fb = Factbase.new
    $global = {}
    $epoch = Time.now
    $loog = Loog::NULL
    $options = Judges::Options.new
    $fb.insert.foo = 1
    Fbe.conclude(judge: 'judge-one') do
      quota_unaware
      on('(exists foo)')
      draw { |n, _prev| n.sum = 10 }
    end
    assert_equal(1, $fb.query("(eq what 'judge-one')").each.to_a.size)
  end
end
