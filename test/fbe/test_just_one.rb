# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'factbase'
require_relative '../test__helper'
require_relative '../../lib/fbe/just_one'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestJustOne < Minitest::Test
  def test_ignores
    fb = Factbase.new
    fb.insert.foo = 'hello dude'
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 'hello dude'
      end
    refute_nil(n)
  end

  def test_injects
    fb = Factbase.new
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 42
      end
    assert_equal(42, n.foo)
  end
end
