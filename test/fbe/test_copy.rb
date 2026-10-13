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
  def test_copies_value_into_target
    seed = Random.new_seed
    value = "значение-#{Random.new(seed).rand(1_000_000)}"
    fb = Factbase.new
    source = fb.insert
    source.foo = value
    target = fb.insert
    Fbe.copy(source, target, except: [])
    assert_equal([value], target['foo'], "the value #{value.inspect} did not reach the target, seed is #{seed}")
  end

  def test_keeps_property_target_already_has
    seed = Random.new_seed
    value = "прежнее-#{Random.new(seed).rand(1_000_000)}"
    fb = Factbase.new
    source = fb.insert
    source.foo = "новое-#{value}"
    target = fb.insert
    target.foo = value
    Fbe.copy(source, target, except: [])
    assert_equal([value], target['foo'], "the value #{value.inspect} of the target was altered, seed is #{seed}")
  end

  def test_copies_every_value_of_multivalued_property
    seed = Random.new_seed
    number = Random.new(seed).rand(1_000_000)
    fb = Factbase.new
    source = fb.insert
    source.foo = "ценность-#{number}"
    source.foo = number
    target = fb.insert
    Fbe.copy(source, target, except: [])
    assert_equal(["ценность-#{number}", number], target['foo'], "not every value of #{number} arrived, seed is #{seed}")
  end

  def test_counts_copied_values
    seed = Random.new_seed
    number = Random.new(seed).rand(1_000_000)
    fb = Factbase.new
    source = fb.insert
    source.foo = "ценность-#{number}"
    source.foo = number
    source.bar = number
    target = fb.insert
    target.bar = "прежнее-#{number}"
    assert_equal(2, Fbe.copy(source, target, except: []), "the count of copied values is wrong, seed is #{seed}")
  end

  def test_copies_properties_outside_except
    seed = Random.new_seed
    value = "остаток-#{Random.new(seed).rand(1_000_000)}"
    fb = Factbase.new
    source = fb.insert
    source.foo = 42
    source.bar = value
    target = fb.insert
    Fbe.copy(source, target, except: ['foo'])
    assert_equal([value], target['bar'], "the value #{value.inspect} was not copied past except, seed is #{seed}")
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
