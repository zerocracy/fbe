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

  def test_uses_one_transaction_for_check_and_insert
    fb = Factbase.new
    seen = []
    probe =
      Class.new do
        define_method(:initialize) do |origin, log|
          @origin = origin
          @log = log
        end
        define_method(:txn) { |&b| @log << :txn and @origin.txn(&b) }
        define_method(:query) { |t, m = nil| @log << :query and @origin.query(t, m) }
        define_method(:insert) { @log << :insert and @origin.insert }
        define_method(:to_term) { |q| @origin.to_term(q) }
      end.new(fb, seen)
    Fbe.if_absent(fb: probe) { |f| f.what = 'x' }
    assert_equal(
      :txn, seen.first,
      'the check and the insert must happen inside one transaction, or two judges can both insert'
    )
    assert_equal(1, fb.query('(always)').each.to_a.size)
  end

  def test_works_inside_a_transaction_of_the_caller
    fb = Factbase.new
    fb.txn do |fbt|
      Fbe.if_absent(fb: fbt) { |f| f.what = 'x' }
      Fbe.if_absent(fb: fbt) { |f| f.what = 'x' }
    end
    assert_equal(
      1, fb.query('(always)').each.to_a.size,
      'a factbase that is already in a transaction must not get a nested one'
    )
  end
end
