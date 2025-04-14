# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/repeatedly'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
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
    assert_equal(42, $fb.query('(always)').each.to_a.first.foo)
  end
end
