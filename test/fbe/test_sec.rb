# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/sec'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestSec < Fbe::Test
  def test_simple
    fb = Factbase.new
    f = fb.insert
    f.seconds = 333
    assert(Fbe.sec(f).start_with?('5m'))
  end
end
