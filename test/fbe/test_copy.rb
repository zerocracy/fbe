# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/copy'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestCopy < Fbe::Test
  def test_copies_a_fact_from_a_parameterized_query
    fb = Factbase.new
    fb.insert.x = 1
    target = Factbase.new.insert
    fb.query('(eq x $wanted)').each(fb, wanted: 1) do |source|
      assert_equal(1, Fbe.copy(source, target))
    end
    assert_equal([1], target['x'])
    assert_nil(target['wanted'])
  end

  def test_keeps_existing_properties_with_query_parameters
    fb = Factbase.new
    fb.insert.x = 1
    target = Factbase.new.insert
    target.x = 99
    fb.query('(always)').each(fb, wanted: 1) do |source|
      assert_equal(0, Fbe.copy(source, target))
    end
    assert_equal([99], target['x'])
    assert_nil(target['wanted'])
  end

  def test_simple_copy
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    source.foo = 42
    target = fb.insert
    target._id = 2
    Fbe.copy(source, target)
    assert_equal(2, target._id)
    assert_equal([2], target['_id'])
    assert_equal(42, target.foo)
    assert_equal([42], target['foo'])
  end

  def test_with_except
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    source.foo = 42
    target = fb.insert
    target._id = 2
    Fbe.copy(source, target, except: ['foo'])
    assert_nil(target['foo'])
  end

  def test_with_except_as_symbol
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    source.foo = 42
    target = fb.insert
    target._id = 2
    Fbe.copy(source, target, except: [:foo])
    assert_nil(target['foo'])
  end
end
