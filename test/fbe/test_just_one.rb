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

  def test_ignores_time_when_existing_fact_has_different_time
    fb = Factbase.new
    fact = fb.insert
    fact.foo = 'bar'
    fact._time = Time.utc(2024, 1, 1, 10, 0, 0)
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 'bar'
        f._time = Time.utc(2026, 5, 20, 15, 30, 0)
      end
    assert_equal(1, fb.size)
    refute_nil(n)
    assert_equal('bar', n.foo)
    assert_equal(Time.utc(2024, 1, 1, 10, 0, 0), n._time)
  end

  def test_ignores_time_when_existing_fact_lacks_time
    fb = Factbase.new
    fact = fb.insert
    fact.foo = 'bar'
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 'bar'
        f._time = Time.now
      end
    assert_equal(1, fb.size)
    refute_nil(n)
    assert_equal('bar', n.foo)
    assert_nil(n['_time'])
  end

  def test_reuses_existing_fact_when_system_attributes_differ
    fb = Factbase.new
    fact = fb.insert
    fact.what = 'issue'
    fact.number = 42
    fact._id = 100
    fact._time = Time.utc(2025, 1, 1)
    fact._version = '0.1.0'
    n =
      Fbe.just_one(fb:) do |f|
        f.what = 'issue'
        f.number = 42
        f._id = 999
        f._time = Time.utc(2026, 2, 2)
        f._version = '1.0.0'
      end
    assert_equal(1, fb.size)
    refute_nil(n)
    assert_equal('issue', n.what)
    assert_equal(42, n.number)
    assert_equal(100, n._id)
    assert_equal(Time.utc(2025, 1, 1), n._time)
    assert_equal('0.1.0', n._version)
  end

  def test_matches_regular_time_attribute_while_ignoring_system_time
    fb = Factbase.new
    moment = Time.utc(2026, 3, 15, 12, 0, 0)
    fact = fb.insert
    fact.what = 'event'
    fact.when = moment
    fact._time = Time.utc(2025, 1, 1)
    n =
      Fbe.just_one(fb:) do |f|
        f.what = 'event'
        f.when = moment
        f._time = Time.utc(2026, 9, 9)
      end
    assert_equal(1, fb.size)
    refute_nil(n)
    assert_equal(moment, n.when)
    assert_equal(Time.utc(2025, 1, 1), n._time)
  end
end
