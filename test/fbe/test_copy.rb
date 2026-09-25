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
  def test_simple_copy
    seed = Random.new_seed
    text = "Ω#{Random.new(seed).rand(1_000_000)}λ"
    fb = Factbase.new
    source = fb.insert
    source.foo = text
    target = fb.insert
    Fbe.copy(source, target)
    assert_equal([text], target['foo'], "the copied foo is not #{text.inspect}, seed is #{seed}")
  end

  def test_with_except
    fb = Factbase.new
    source = fb.insert
    source.foo = 42
    target = fb.insert
    Fbe.copy(source, target, except: ['foo'])
    assert_nil(target['foo'], 'the excluded foo is in the target anyway')
  end

  def test_dont_copy_id_by_default
    fb = Factbase.new
    source = fb.insert
    source._id = 42
    target = fb.insert
    Fbe.copy(source, target)
    assert_nil(target['_id'], 'the identity of the source is in the target')
  end

  def test_dont_copy_time_by_default
    fb = Factbase.new
    source = fb.insert
    source._time = Time.now
    target = fb.insert
    Fbe.copy(source, target)
    assert_nil(target['_time'], 'the timestamp of the source is in the target')
  end

  def test_dont_copy_id_when_except_given
    fb = Factbase.new
    source = fb.insert
    source._id = 7
    source.foo = 42
    target = fb.insert
    Fbe.copy(source, target, except: ['foo'])
    assert_nil(target['_id'], 'the except list replaces the internals instead of adding to them')
  end

  def test_dont_count_internals_as_copied
    fb = Factbase.new
    source = fb.insert
    source._id = 3
    source._time = Time.now
    source.foo = 42
    source.foo = 7
    target = fb.insert
    assert_equal(2, Fbe.copy(source, target), 'the internals are among the copied values')
  end
end
