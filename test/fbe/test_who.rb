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
    error = assert_raises(Fbe::Error) { Fbe.who(f, global:, options:, loog: Loog::NULL) }
    assert_equal('The :who property ("yegor") is not a number', error.message)
  end

  def test_refuses_a_fact_without_who
    fb = Factbase.new
    f = fb.insert
    global = {}
    options = Judges::Options.new({})
    error = assert_raises(Fbe::Error) { Fbe.who(f, global:, options:, loog: Loog::NULL) }
    assert_equal('There is no :who property', error.message)
  end

  def test_with_custom_property
    fb = Factbase.new
    f = fb.insert
    f.author_id = 526_301
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('@yegor256', Fbe.who(f, :author_id, global:, options:, loog: Loog::NULL))
  end

  def test_refuses_when_custom_property_is_absent
    fb = Factbase.new
    f = fb.insert
    f.who = 444
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    error = assert_raises(Fbe::Error) { Fbe.who(f, :author_id, global:, options:, loog: Loog::NULL) }
    assert_equal('There is no :author_id property', error.message)
  end

  def test_with_numeric_string_id
    fb = Factbase.new
    f = fb.insert
    f.who = '526301'
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('@yegor256', Fbe.who(f, global:, options:, loog: Loog::NULL))
  end
end
