# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/overwrite'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestOverwrite < Fbe::Test
  def test_simple_overwrite
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    f.bar = 'hey you друг'
    f.many = 3
    f.many = 3.14
    Fbe.overwrite(f, 'foo', 55, fb:)
    assert_equal(55, fb.query('(always)').each.to_a.first['foo'].first)
    assert_equal('hey you друг', fb.query('(always)').each.to_a.first['bar'].first)
    assert_equal(2, fb.query('(always)').each.to_a.first['many'].size)
  end

  def test_avoids_duplicates
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f._job = 42
    f.foo = 'hello'
    Fbe.overwrite(f, 'foo', 'bye', fb:)
    f2 = fb.query('(exists foo)').each.to_a.first
    assert_equal([1], f2['_id'])
    assert_equal([42], f2['_job'])
    assert_equal(['bye'], f2['foo'])
  end

  def test_no_need_to_overwrite
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    fb.insert._id = 2
    Fbe.overwrite(f, 'foo', 42, fb:)
    assert_equal(1, fb.query('(always)').each.to_a.first._id)
  end

  def test_simple_insert
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    Fbe.overwrite(f, 'foo', 42, fb:)
    assert_equal(42, fb.query('(always)').each.to_a.first['foo'].first)
  end

  def test_without_id
    fb = Factbase.new
    f = fb.insert
    f.foo = 43
    assert_raises(StandardError) do
      Fbe.overwrite(f, 'foo', 42, fb:)
    end
  end

  def test_without_previous_property
    fb = Factbase.new
    global = {}
    options = Judges::Options.new
    loog = Loog::NULL
    fbx = Fbe.fb(fb:, global:, options:, loog:)
    f = fbx.insert
    f.foo = 42
    fbx.insert
    before = f._id
    Fbe.overwrite(f, 'bar', 44, fb: fbx)
    assert_equal(before, fbx.query('(eq bar 44)').each.first._id)
  end

  def test_safe_insert
    fb = Factbase.new
    f1 = fb.insert
    f1.bar = 'a'
    f2 = fb.insert
    f2.bar = 'b'
    f2._id = 2
    f3 = fb.insert
    f3._id = 1
    Fbe.overwrite(f3, 'foo', 42, fb:)
    assert_equal(3, fb.size)
  end

  def test_overwrites_in_transaction
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new(job_id: 42)
    $loog = Loog::Buffer.new
    Fbe.fb.txn do |fbt|
      fbt.insert.then do |f|
        f.issue = 444
        f.where = 'github'
        f.repository = 555
        f.who = 887
        f.when = Time.now
        f.foo = 1
      end
    end
    f1 = Fbe.fb.query('(always)').each.to_a.first
    Fbe.overwrite(f1, 'foo', 'bar')
    f2 = Fbe.fb.query('(always)').each.to_a.first
    assert_equal('bar', f2.foo)
  end

  def test_overwrite_with_hash_single_property
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    f.bar = 'hey you друг'
    Fbe.overwrite(f, {foo: 55}, fb:)
    assert_equal(55, fb.query('(always)').each.to_a.first['foo'].first)
    assert_equal('hey you друг', fb.query('(always)').each.to_a.first['bar'].first)
  end

  def test_overwrite_with_hash_multiple_properties
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    f.bar = 'hey you друг'
    f.baz = 'old_value'
    Fbe.overwrite(f, { foo: 55, bar: 'hello', baz: 'new_value' }, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal(55, result['foo'].first)
    assert_equal('hello', result['bar'].first)
    assert_equal('new_value', result['baz'].first)
  end

  def test_overwrite_with_hash_symbol_keys
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    Fbe.overwrite(f, { foo: 100, bar: 'new_property' }, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal(100, result['foo'].first)
    assert_equal('new_property', result['bar'].first)
  end

  def test_overwrite_with_hash_string_keys
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    Fbe.overwrite(f, { 'foo' => 200, 'bar' => 'string_key' }, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal(200, result['foo'].first)
    assert_equal('string_key', result['bar'].first)
  end

  def test_overwrite_with_hash_preserves_other_properties
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    f.bar = 'hey you друг'
    f.many = 3
    f.many = 3.14
    Fbe.overwrite(f, { foo: 55 }, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal(55, result['foo'].first)
    assert_equal('hey you друг', result['bar'].first)
    assert_equal(2, result['many'].size)
  end

  def test_overwrite_with_hash_empty_hash
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    Fbe.overwrite(f, {}, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal(42, result['foo'].first)
  end

  def test_overwrite_with_hash_mixed_key_types
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    Fbe.overwrite(f, { foo: 100, 'bar' => 'mixed', baz: 'symbol' }, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal(100, result['foo'].first)
    assert_equal('mixed', result['bar'].first)
    assert_equal('symbol', result['baz'].first)
  end

  def test_overwrite_with_hash_arrays_as_values
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    Fbe.overwrite(f, { foo: [1, 2, 3], bar: ['a', 'b'] }, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal([1, 2, 3], result['foo'])
    assert_equal(['a', 'b'], result['bar'])
  end
end
