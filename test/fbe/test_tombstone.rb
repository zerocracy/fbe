# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/tombstone'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestTombstone < Fbe::Test
  def test_simple
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    ts.bury!(41, 13)
    ts.bury!(42, 13)
    ts.bury!(42, 999)
    assert(ts.has?(41, 13))
    assert(ts.has?(42, 999))
    refute(ts.has?(8, 7))
    refute(ts.has?(43, 999))
    refute(ts.has?(43, 990))
  end
end
