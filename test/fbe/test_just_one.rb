# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/just_one'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestJustOne < Fbe::Test
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

  def test_ignores_system_attributes_when_matching
    fb = Factbase.new
    fb.insert.foo = 'hello dude'
    n =
      Fbe.just_one(fb:) do |f|
        f._id = 42
        f.foo = 'hello dude'
      end
    refute_nil(n)
  end

  def test_raises_on_empty_value
    assert_raises(StandardError) do
      Fbe.just_one(fb: Factbase.new) do |f|
        f.foo = ''
      end
    end
  end

  def test_raises_on_nil
    assert_raises(StandardError) do
      Fbe.just_one(fb: Factbase.new) do |f|
        f.foo = nil
      end
    end
  end
end
