# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/issue'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
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

  def test_with_float_ids
    fb = Factbase.new
    f = fb.insert
    f.repository = 323.0
    f.issue = 333.0
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('yegor256/test#333', Fbe.issue(f, global:, options:, loog: Loog::NULL))
  end

  def test_with_non_numeric_repository
    fb = Factbase.new
    f = fb.insert
    f.repository = 'yegor'
    f.issue = 333
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_raises(Fbe::Error) { Fbe.issue(f, global:, options:, loog: Loog::NULL) }
  end
end
