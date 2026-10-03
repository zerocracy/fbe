# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/who'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
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

  def test_with_float_id
    fb = Factbase.new
    f = fb.insert
    f.who = 444.0
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('@torvalds', Fbe.who(f, global:, options:, loog: Loog::NULL))
  end

  def test_with_non_numeric_id
    fb = Factbase.new
    f = fb.insert
    f.who = 'yegor'
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_raises(Fbe::Error) { Fbe.who(f, global:, options:, loog: Loog::NULL) }
  end

  def test_rejects_multiple_user_ids
    fb = Factbase.new
    f = fb.insert
    f.who = [444, 445]
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_raises(Fbe::Error) { Fbe.who(f, global:, options:, loog: Loog::NULL) }
  end

  def test_rejects_multiple_values_in_a_custom_property
    fb = Factbase.new
    f = fb.insert
    f.owner = [444, 445]
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_raises(Fbe::Error) { Fbe.who(f, :owner, global:, options:, loog: Loog::NULL) }
  end
end
