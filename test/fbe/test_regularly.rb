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
      raise Factbase::Rollback
    end
    assert_equal(0, fb.size)
  end
end
