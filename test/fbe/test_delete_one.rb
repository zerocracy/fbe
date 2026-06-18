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

  def test_preserves_system_props_on_decorated_fb
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '3' } }
    )
    fb = Factbase.new
    global = {}
    options = Judges::Options.new(job_id: 42)
    loog = Loog::NULL
    fbx = Fbe.fb(fb:, global:, options:, loog:)
    fbx.insert.then { |f| f.foo = 1 }
    fbx.insert.then { |f| f.foo = 2 }
    target = fbx.query('(eq foo 1)').each.first
    target.bar = 11
    target.bar = 22
    snapshot = { id: target._id, time: target._time, version: target._version, job: target._job }
    Fbe.delete_one(target, 'bar', 11, fb: fbx)
    after = fbx.query('(eq foo 1)').each.first
    assert_equal(snapshot[:id], after._id)
    assert_equal(snapshot[:time], after._time)
    assert_equal(snapshot[:version], after._version)
    assert_equal(snapshot[:job], after._job)
    assert_equal([22], after['bar'])
  end
end
