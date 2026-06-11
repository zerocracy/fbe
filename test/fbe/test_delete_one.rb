# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/delete_one'
require_relative '../../lib/fbe/fb'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestDeleteOne < Fbe::Test
  def test_deletes_one_value
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    f.foo = 'hello'
    f._id = 555
    Fbe.delete_one(f, 'foo', 42, fb:)
    assert_equal(1, fb.size)
    assert_equal(1, fb.query('(exists foo)').each.to_a.size)
    assert_equal(0, fb.query('(eq foo 42)').each.to_a.size)
    assert_equal(['hello'], fb.query('(exists foo)').each.first['foo'])
  end

  def test_deletes_when_many
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    f.foo = 'hello'
    f.bar = 44
    f._id = 555
    Fbe.delete_one(f, 'bar', 44, fb:)
    assert_equal(1, fb.size)
    assert_equal(1, fb.query('(exists foo)').each.to_a.size)
    assert_equal(1, fb.query('(eq foo 42)').each.to_a.size)
    assert_equal([42, 'hello'], fb.query('(exists foo)').each.first['foo'])
  end

  def test_deletes_nothing
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    f.foo = 'hello'
    f._id = 555
    Fbe.delete_one(f, 'bar', 42, fb:)
    assert_equal(1, fb.size)
    assert_equal(1, fb.query('(exists foo)').each.to_a.size)
    assert_equal(1, fb.query('(eq foo 42)').each.to_a.size)
  end

  def test_does_not_recreate_fact_when_value_not_present
    opts = Judges::Options.new(['testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    f = fb.insert
    f.what = 'test'
    f.foo = 1
    f.foo = 2
    f.foo = 3
    id = f._id
    Fbe.delete_one(f, 'foo', 99, fb:)
    r = fb.query('(eq what "test")').each.first
    assert_equal(1, fb.query('(eq what "test")').each.to_a.size)
    assert_equal(id, r._id, 'The _id must not change when value is not in the array')
    assert_equal([1, 2, 3], r['foo'])
  end

  def test_keeps_original_fact_when_reinsert_fails
    reject = false
    fb =
      Factbase::Pre.new(Factbase.new) do |_f, _fbt|
        raise(RuntimeError, 'insert failed') if reject
      end
    f = fb.insert
    f._id = 555
    f.foo = 42
    f.foo = 'hello'
    f.bar = 'keep'
    reject = true
    assert_raises(RuntimeError) { Fbe.delete_one(f, 'foo', 42, fb:) }
    after = fb.query('(eq _id 555)').each.to_a
    assert_equal(1, after.size)
    assert_equal([42, 'hello'], after.first['foo'])
    assert_equal(['keep'], after.first['bar'])
  end
end
