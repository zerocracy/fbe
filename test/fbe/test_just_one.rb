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
  def test_tells_apart_two_times_inside_one_second
    fb = Factbase.new
    early = Time.utc(2026, 9, 17, 20, 6, 10, 100_000)
    late = Time.utc(2026, 9, 17, 20, 6, 10, 900_000)
    Fbe.just_one(fb:) do |f|
      f.what = 'thing'
      f.when = early
    end
    Fbe.just_one(fb:) do |f|
      f.what = 'thing'
      f.when = late
    end
    assert_equal(2, fb.size)
  end

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

  def test_raises_without_block
    assert_raises(Fbe::Error, 'just_one accepted a call without a block') do
      Fbe.just_one(fb: Factbase.new)
    end
  end

  def test_dont_insert_fact_without_block
    fb = Factbase.new
    begin
      Fbe.just_one(fb:)
    rescue Fbe::Error
      nil
    end
    assert_equal(0, fb.size, 'just_one inserted a fact without a block')
  end

  def test_finds_a_stored_value_with_apostrophe
    fb = Factbase.new
    f = fb.insert
    f.foo = "it's"
    f.bar = 1
    n = Fbe.just_one(fb:) { |g| g.foo = "it's" }
    assert_equal([1], n['bar'], 'just_one did not return the fact with an apostrophe')
    assert_equal(1, fb.size, 'just_one inserted a duplicate of the fact with an apostrophe')
  end

  def test_finds_a_stored_time_by_local_time
    fb = Factbase.new
    f = fb.insert
    f.when = Time.utc(2024, 5, 1, 10)
    f.bar = 2
    n = Fbe.just_one(fb:) { |g| g.when = Time.new(2024, 5, 1, 13, 0, 0, '+03:00') }
    assert_equal([2], n['bar'], 'just_one did not match a non-UTC time')
    assert_equal(1, fb.size, 'just_one inserted a duplicate for a non-UTC time')
  end
end
