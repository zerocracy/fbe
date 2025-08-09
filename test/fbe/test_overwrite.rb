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
    assert_raises(StandardError) do
      Fbe.overwrite(f, 'foo', 42, fb:)
    end
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
end
