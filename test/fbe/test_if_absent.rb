# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require 'tmpdir'
require_relative '../../lib/fbe/if_absent'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestIfAbsent < Fbe::Test
  def test_tells_apart_two_times_inside_one_second
    fb = Factbase.new
    early = Time.utc(2026, 9, 17, 20, 6, 10, 100_000)
    late = Time.utc(2026, 9, 17, 20, 6, 10, 900_000)
    refute_nil(
      Fbe.if_absent(fb:) do |f|
        f.what = 'thing'
        f.when = early
      end
    )
    refute_nil(
      Fbe.if_absent(fb:) do |f|
        f.what = 'thing'
        f.when = late
      end
    )
    assert_nil(
      Fbe.if_absent(fb:) do |f|
        f.what = 'thing'
        f.when = early
      end
    )
    assert_equal(2, fb.size)
  end

  def test_ignores
    fb = Factbase.new
    fb.insert.foo = 'hello dude'
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = 'hello dude'
      end
    assert_nil(n)
  end

  def test_raises_on_empty_value
    assert_raises(StandardError) do
      Fbe.if_absent(fb: Factbase.new) do |f|
        f.foo = ''
      end
    end
  end

  def test_raises_on_nil
    fb = Factbase.new
    fb.insert.foo = 42
    assert_raises(StandardError) do
      Fbe.if_absent(fb: Factbase.new) do |f|
        f.foo = nil
      end
    end
  end

  def test_ignores_with_time
    fb = Factbase.new
    t = Time.now
    fb.insert.foo = t
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = t
      end
    assert_nil(n)
  end

  def test_injects
    fb = Factbase.new
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = 42
      end
    assert_equal(42, n.foo)
  end

  def test_injects_and_reads
    Fbe.if_absent(fb: Factbase.new) do |f|
      f.foo = 42
      assert_equal(42, f.foo)
    end
  end

  def test_complex_ignores
    fb = Factbase.new
    fact = fb.insert
    fact.foo = 'hello, "dude"!'
    fact.abc = 42
    t = Time.now
    fact.z = t
    fact.bar = 3.14
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = 'hello, "dude"!'
        f.abc = 42
        f.z = t
        f.bar = 3.14
      end
    assert_nil(n)
  end

  def test_ignores_system_attributes_when_matching
    fb = Factbase.new
    fb.insert.foo = 'hello dude'
    n =
      Fbe.if_absent(fb:) do |f|
        f._id = 42
        f.foo = 'hello dude'
      end
    assert_nil(n)
  end

  def test_ignores_time_when_matching
    seed = Random.new_seed
    rnd = Random.new(seed)
    fb = Factbase.new
    name = "ёжик #{rnd.rand(1000)}"
    old = fb.insert
    old.foo = name
    old._time = Time.utc(2025, 1, 1) + rnd.rand(86_400)
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = name
        f._time = Time.utc(2026, 1, 1) + rnd.rand(86_400)
      end
    assert_nil(n, "if_absent matched on _time and returned a new fact, seed #{seed}")
  end

  def test_ignores_fact_without_time
    seed = Random.new_seed
    rnd = Random.new(seed)
    fb = Factbase.new
    name = "ürün #{rnd.rand(1000)}"
    fb.insert.foo = name
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = name
        f._time = Time.utc(2026, 1, 1) + rnd.rand(86_400)
      end
    assert_nil(n, "if_absent did not find the fact that has no _time, seed #{seed}")
  end

  def test_complex_injects
    fb = Factbase.new
    fact = fb.insert
    fact.foo = 'hello, dude!'
    fact.abc = 42
    t = Time.now
    fact.z = t
    fact.bar = 3.14
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = "hello, \\\"dude\\\" \\' \\' ( \n\n ) (!   '"
        f.abc = 42
        f.z = t + 1
        f.bar = 3.15
      end
    refute_nil(n)
  end

  def test_raises_without_block
    fb = Factbase.new
    error = assert_raises(Fbe::Error) { Fbe.if_absent(fb:) }
    assert_equal('A block is required by if_absent', error.message)
    assert_equal(0, fb.size, 'if_absent inserted a fact without a block')
  end
end
