# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/who'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestWho < Fbe::Test
  def test_simple
    fb = Factbase.new
    f = fb.insert
    f.who = 444
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('@torvalds', Fbe.who(f, global:, options:, loog: Loog::NULL))
  end
end
