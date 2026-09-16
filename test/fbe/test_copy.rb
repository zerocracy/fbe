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
  def test_copies_a_value
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    source.foo = 42
    target = fb.insert
    target._id = 2
    Fbe.copy(source, target)
    assert_equal(42, target.foo)
  end

  def test_leaves_an_existing_property_alone
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    target = fb.insert
    target._id = 2
    Fbe.copy(source, target)
    assert_equal([2], target['_id'])
  end

  def test_copies_every_value_of_a_property
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    source.foo = 42
    source.foo = 7
    target = fb.insert
    target._id = 2
    Fbe.copy(source, target)
    assert_equal([42, 7], target['foo'])
  end

  def test_counts_the_values_it_copied
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    source.foo = 42
    source.foo = 7
    source.bar = 'x'
    target = fb.insert
    target._id = 2
    assert_equal(3, Fbe.copy(source, target))
  end

  def test_with_except
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    source.foo = 42
    source.bar = 'x'
    target = fb.insert
    target._id = 2
    Fbe.copy(source, target, except: ['foo'])
    assert_nil(target['foo'])
  end

  def test_keeps_what_except_did_not_name
    fb = Factbase.new
    source = fb.insert
    source._id = 1
    source.foo = 42
    source.bar = 'x'
    target = fb.insert
    target._id = 2
    Fbe.copy(source, target, except: ['foo'])
    assert_equal('x', target.bar)
  end
end
