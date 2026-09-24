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

  def test_raises_on_block_without_attributes
    seed = Random.new_seed
    fb = Factbase.new
    fb.insert.kind = "чужой факт #{Random.new(seed).rand(1_000_000)}"
    assert_raises(Fbe::Error, "if_absent matched an unrelated fact by an empty key, seed #{seed}") do
      Fbe.if_absent(fb:, always: false) { nil }
    end
  end

  def test_raises_on_block_without_attributes_when_always
    seed = Random.new_seed
    fb = Factbase.new
    fb.insert.kind = "чужой факт #{Random.new(seed).rand(1_000_000)}"
    assert_raises(Fbe::Error, "if_absent returned an unrelated fact by an empty key, seed #{seed}") do
      Fbe.if_absent(fb:, always: true) { nil }
    end
  end

  def test_raises_on_block_with_only_system_attributes
    seed = Random.new_seed
    random = Random.new(seed)
    fb = Factbase.new
    fb.insert.kind = "чужой факт #{random.rand(1_000_000)}"
    assert_raises(Fbe::Error, "if_absent matched an unrelated fact by system attributes, seed #{seed}") do
      Fbe.if_absent(fb:, always: false) do |f|
        f._id = random.rand(1..1_000_000)
        f._time = Time.at(random.rand(1_000_000_000)).utc
        f._version = random.rand(1..1_000)
      end
    end
  end

  def test_dont_insert_fact_without_attributes
    fb = Factbase.new
    begin
      Fbe.if_absent(fb:, always: false) { nil }
    rescue Fbe::Error
      nil
    end
    assert_equal(0, fb.size, 'if_absent inserted a blank fact for an empty key')
  end
end
