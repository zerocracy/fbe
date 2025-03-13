# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'
require_relative '../../lib/fbe/sec'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestSec < Minitest::Test
  def test_simple
    fb = Factbase.new
    f = fb.insert
    f.seconds = 333
    assert_equal('5 minutes', Fbe.sec(f))
  end
end
