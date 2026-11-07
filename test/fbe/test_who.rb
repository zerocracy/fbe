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

  def test_cannot_name_user_with_non_finite_id
    seed = Random.new_seed
    value = [Float::NAN, Float::INFINITY, -Float::INFINITY].sample(random: Random.new(seed))
    fb = Factbase.new
    f = fb.insert
    f.who = value
    options = Judges::Options.new({ 'testing' => true })
    assert_raises(Fbe::Error, "the user #{value} is named, seed is #{seed}") do
      Fbe.who(f, global: {}, options:, loog: Loog::NULL)
    end
  end
end
