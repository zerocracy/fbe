# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/copy'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestCopy < Fbe::Test
  def test_simple_copy
    fb = Factbase.new
    f1 = fb.insert
    f1._id = 1
    f1.foo = 42
    f2 = fb.insert
    f2._id = 2
    Fbe.copy(f1, f2)
    assert_equal(2, f2._id)
    assert_equal(42, f2.foo)
  end

  def test_with_except
    fb = Factbase.new
    f1 = fb.insert
    f1._id = 1
    f1.foo = 42
    f2 = fb.insert
    f2._id = 2
    Fbe.copy(f1, f2, except: ['foo'])
    assert_nil(f2['foo'])
  end
end
