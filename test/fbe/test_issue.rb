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

  def test_rejects_fractional_ids
    fb = Factbase.new
    f = fb.insert
    f.repository = 323.6
    f.issue = 333.6
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_raises(Fbe::Error) { Fbe.issue(f, global:, options:, loog: Loog::NULL) }
    f.repository = 323
    assert_raises(Fbe::Error) { Fbe.issue(f, global:, options:, loog: Loog::NULL) }
  end

  def test_preserves_large_integer_ids
    fb = Factbase.new
    f = fb.insert
    f.repository = (2**53) + 1
    f.issue = (2**53) + 3
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    api = Object.new
    api.define_singleton_method(:repo_name_by_id) { |id| id.to_s }
    result = Fbe.stub(:octo, ->(**_kwargs) { api }) do
      Fbe.issue(f, global:, options:, loog: Loog::NULL)
    end
    assert_equal("#{(2**53) + 1}##{(2**53) + 3}", result)
  end
end
