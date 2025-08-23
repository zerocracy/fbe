# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/delete_one'
require_relative '../../lib/fbe/fb'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
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
end
