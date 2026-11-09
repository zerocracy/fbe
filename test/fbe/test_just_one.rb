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

  def test_reads_attribute_back_inside_block
    fb = Factbase.new
    Fbe.just_one(fb:) do |f|
      f.foo = 42
      assert_equal(42, f.foo)
    end
  end

  def test_reads_nothing_before_anything_is_set
    fb = Factbase.new
    Fbe.just_one(fb:) do |f|
      assert_nil(f.bar)
      assert_equal(0, fb.size)
      f.foo = 42
    end
    assert_equal(1, fb.size)
  end

  def test_last_value_wins_inside_block
    fb = Factbase.new
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 1
        f.foo = 2
        assert_equal(2, f.foo)
      end
    assert_equal([2], n['foo'])
    assert_equal(1, fb.size)
  end

  def test_reads_back_a_time_value_inside_block
    fb = Factbase.new
    stamp = Time.utc(2026, 1, 2, 3, 4, 5)
    n =
      Fbe.just_one(fb:) do |f|
        f.when = stamp
        assert_equal(stamp, f.when)
      end
    assert_equal([stamp], n['when'])
  end

  def test_finds_the_same_fact_when_read_inside_the_block
    fb = Factbase.new
    2.times do
      Fbe.just_one(fb:) do |f|
        f.foo = 42
        assert_equal(42, f.foo)
      end
    end
    assert_equal(1, fb.size)
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
end
