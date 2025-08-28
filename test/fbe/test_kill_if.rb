# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/fb'
require_relative '../../lib/fbe/kill_if'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestKillIf < Fbe::Test
  def test_deletes_a_few
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    f.hey = 4
    f.id = 555
    Fbe.kill_if([f], fb:, fid: 'id')
    assert_equal(0, fb.size)
  end
end
