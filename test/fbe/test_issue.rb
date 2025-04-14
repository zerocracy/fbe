# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/issue'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestIssue < Fbe::Test
  def test_simple
    fb = Factbase.new
    f = fb.insert
    f.repository = 323
    f.issue = 333
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('yegor256/test#333', Fbe.issue(f, global:, options:, loog: Loog::NULL))
  end
end
