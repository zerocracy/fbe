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
end
