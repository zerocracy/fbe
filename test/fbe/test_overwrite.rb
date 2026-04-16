# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/overwrite'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestOverwrite < Fbe::Test # rubocop:disable Metrics/ClassLength
  def test_simple_overwrite
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    f.bar = 'hey you друг'
    f.many = 3
    f.many = 3.14
    Fbe.overwrite(f, 'foo', 55, fb:)
    assert_equal(55, fb.query('(always)').each.first['foo'].first)
    assert_equal('hey you друг', fb.query('(always)').each.first['bar'].first)
    assert_equal(2, fb.query('(always)').each.first['many'].size)
  end

  def test_avoids_duplicates
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f._job = 42
    f.foo = 'hello'
    Fbe.overwrite(f, 'foo', 'bye', fb:)
    fact = fb.query('(exists foo)').each.first
    assert_equal([1], fact['_id'])
    assert_equal([42], fact['_job'])
    assert_equal(['bye'], fact['foo'])
  end

  def test_skips_overwrite_with_hash
    c = 0
    fb =
      Factbase::Pre.new(Factbase.new) do |f, _fbt|
        f.pos = c
        c += 1
      end
    f = fb.insert
    assert_equal(0, f.pos)
    f._id = 1
    f.foo = 42
    Fbe.overwrite(f, 'foo', 42, fb:)
    f = fb.query('(always)').each.to_a.first
    assert_equal(0, f.pos)
  end

  def test_simple_insert
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    Fbe.overwrite(f, 'foo', 42, fb:)
    assert_equal(42, fb.query('(always)').each.first['foo'].first)
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
    first = fb.insert
    first.bar = 'a'
    second = fb.insert
    second.bar = 'b'
    second._id = 2
    third = fb.insert
    third._id = 1
    Fbe.overwrite(third, 'foo', 42, fb:)
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
    before = Fbe.fb.query('(always)').each.first
    Fbe.overwrite(before, 'foo', 'bar')
    after = Fbe.fb.query('(always)').each.first
    assert_equal('bar', after.foo)
  end

  def test_overwrite_with_hash_single_property
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    f.bar = 'hey you друг'
    Fbe.overwrite(f, { foo: 55 }, fb:)
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

  def test_skips_overwrite_with_single_value
    c = 0
    fb =
      Factbase::Pre.new(Factbase.new) do |f, _fbt|
        f.pos = c
        c += 1
      end
    f = fb.insert
    assert_equal(0, f.pos)
    f._id = 1
    f.foo = 42
    Fbe.overwrite(f, { foo: 42 }, fb:)
    f = fb.query('(always)').each.to_a.first
    assert_equal(0, f.pos)
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
    Fbe.overwrite(f, { foo: [1, 2, 3], bar: %w[a b] }, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal([1, 2, 3], result['foo'])
    assert_equal(%w[a b], result['bar'])
  end

  def test_overwrite_with_hash_rejects_nil_values
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    assert_raises(Fbe::Error, 'The value for bar is nil') do
      Fbe.overwrite(f, { foo: 55, bar: nil }, fb:)
    end
  end

  def test_overwrite_with_hash_nil_fact
    fb = Factbase.new
    assert_raises(Fbe::Error, 'The fact is nil') do
      Fbe.overwrite(nil, { foo: 42 }, fb:)
    end
  end

  def test_overwrite_with_hash_nil_fb
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    assert_raises(Fbe::Error, 'The fb is nil') do
      Fbe.overwrite(f, { foo: 55 }, fb: nil)
    end
  end

  def test_overwrite_with_hash_custom_fid
    fb = Factbase.new
    f = fb.insert
    f.custom_id = 123
    f.foo = 42
    Fbe.overwrite(f, { foo: 55 }, fb:, fid: 'custom_id')
    result = fb.query('(always)').each.to_a.first
    assert_equal(55, result['foo'].first)
  end

  def test_overwrite_with_hash_missing_custom_fid
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    assert_raises(Fbe::Error, 'There is no custom_id in the fact, cannot use Fbe.overwrite') do
      Fbe.overwrite(f, { foo: 55 }, fb:, fid: 'custom_id')
    end
  end

  def test_overwrite_with_hash_fact_not_found_in_db
    fb = Factbase.new
    f = fb.insert
    f._id = 999
    f.foo = 42
    fb.txn do |fbt|
      n = fbt.insert
      n._id = 999
      n.foo = 42
    end
    fb.query('(eq _id 999)').delete!
    assert_raises(Fbe::Error, 'No facts by _id = 999') do
      Fbe.overwrite(f, { foo: 55 }, fb:)
    end
  end

  def test_overwrite_with_hash_complex_data_types
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    data = { string: 'hello', number: 42, float: 3.14, array: [1, 2, 3] }
    Fbe.overwrite(f, data, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal('hello', result['string'].first)
    assert_equal(42, result['number'].first)
    assert_in_delta(3.14, result['float'].first)
    assert_equal([1, 2, 3], result['array'])
  end

  def test_overwrite_with_hash_very_large_hash
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    props = {}
    100.times { |i| props["prop_#{i}"] = "value_#{i}" }
    Fbe.overwrite(f, props, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal('value_0', result['prop_0'].first)
    assert_equal('value_50', result['prop_50'].first)
    assert_equal('value_99', result['prop_99'].first)
  end

  def test_overwrite_with_hash_special_characters_in_keys
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    keys = {
      'key_with_underscores' => 'value1',
      'key_with_dashes' => 'value2',
      'key_with_dots' => 'value3',
      'key_with_slashes' => 'value4',
      'key123' => 'value5'
    }
    Fbe.overwrite(f, keys, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal('value1', result['key_with_underscores'].first)
    assert_equal('value2', result['key_with_dashes'].first)
    assert_equal('value3', result['key_with_dots'].first)
    assert_equal('value4', result['key_with_slashes'].first)
    assert_equal('value5', result['key123'].first)
  end

  def test_overwrite_with_hash_unicode_values
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.foo = 42
    data = { emoji: '🚀', chinese: '你好世界', arabic: 'مرحبا بالعالم', russian: 'Привет мир', japanese: 'こんにちは世界' }
    Fbe.overwrite(f, data, fb:)
    result = fb.query('(always)').each.to_a.first
    assert_equal('🚀', result['emoji'].first)
    assert_equal('你好世界', result['chinese'].first)
    assert_equal('مرحبا بالعالم', result['arabic'].first)
    assert_equal('Привет мир', result['russian'].first)
    assert_equal('こんにちは世界', result['japanese'].first)
  end
end
