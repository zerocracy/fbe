# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/delete'
require_relative '../../lib/fbe/fb'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestDelete < Fbe::Test
  def test_deletes_one_property
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    f.hey = 4
    f._id = 555
    Fbe.delete(f, 'foo', 'bar', fb:)
    assert_equal(1, fb.size)
    assert_equal(1, fb.query('(exists hey)').each.to_a.size)
    assert_equal(4, fb.query('(exists hey)').each.first.hey)
  end

  def test_deletes_when_many
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    f.foo = 'hello'
    f.bar = 4
    f._id = 555
    Fbe.delete(f, 'bar', fb:)
    assert_equal(1, fb.size)
    assert_equal([42, 'hello'], fb.query('(exists foo)').each.first['foo'])
  end

  def test_deletes_two_properties
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    f.hey = 4
    f._id = 555
    Fbe.delete(f, 'foo', 'hey', fb:)
    assert_equal(1, fb.size)
    assert_equal(0, fb.query('(exists hey)').each.to_a.size)
  end

  def test_deletes_safely
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new(job_id: 42)
    $loog = Loog::Buffer.new
    f = Fbe.fb.insert
    f.foo = 'hello'
    Fbe.delete(f, 'foo')
    f2 = Fbe.fb.query('(always)').each.to_a.first
    assert_equal([1], f2['_id'])
    assert_equal([42], f2['_job'])
  end

  def test_deletes_id
    fb = Factbase.new
    f = fb.insert
    f._id = 44
    Fbe.delete(f, '_id', fb:)
    f2 = fb.query('(always)').each.to_a.first
    assert_nil(f2['_id'])
    assert_empty(f2.all_properties)
  end

  def test_deletes_in_transaction
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
    Fbe.delete(f1, 'foo')
    f2 = Fbe.fb.query('(always)').each.to_a.first
    assert_nil(f2['foo'])
  end

  def test_deletes_when_duplicate_id
    fb = Factbase.new
    f = fb.insert
    f._id = 44
    f._id = 45
    Fbe.delete(f, '_id', fb:)
    f2 = fb.query('(always)').each.to_a.first
    assert_nil(f2['_id'])
  end
end
