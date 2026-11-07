# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/fb'
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

  def test_returns_the_fact_it_already_has
    fb = Factbase.new
    f = fb.insert
    f.foo = 1
    f.bar = 'x'
    n = Fbe.just_one(fb:) { |g| g.foo = 1 }
    assert_equal(['x'], n['bar'], 'just_one did not return the stored fact')
    assert_equal(1, fb.size, 'just_one inserted a duplicate fact')
  end

  def test_inserts_once_when_called_twice
    fb = Factbase.new
    Fbe.just_one(fb:) { |f| f.foo = 7 }
    n = Fbe.just_one(fb:) { |f| f.foo = 7 }
    n.bar = 'y'
    assert_equal(1, fb.size, 'the second call of just_one inserted a new fact')
    assert_equal(1, fb.query('(eq bar "y")').each.to_a.size, 'property did not land on the stored fact')
  end

  def test_inserts_when_only_another_fact_exists
    fb = Factbase.new
    fb.insert.foo = 1
    n = Fbe.just_one(fb:) { |f| f.foo = 2 }
    assert_equal([2], n['foo'], 'just_one returned a fact that does not match')
    assert_equal(2, fb.size, 'just_one did not insert a new fact')
  end

  def test_returns_the_same_id_on_decorated_fb
    fb = Factbase.new
    x = Fbe.fb(fb:, global: {}, options: Judges::Options.new, loog: Loog::NULL)
    first = Fbe.just_one(fb: x) { |f| f.foo = 3 }
    second = Fbe.just_one(fb: x) { |f| f.foo = 3 }
    assert_equal(first['_id'], second['_id'], 'just_one returned another fact on the second call')
    assert_equal(1, fb.size, 'just_one inserted a duplicate on the decorated factbase')
  end
end
