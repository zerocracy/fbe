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

  def test_refuses_a_nil_fact
    error =
      assert_raises(Fbe::Error) do
        Fbe.who(nil, global: {}, options: Judges::Options.new({ 'testing' => true }), loog: Loog::NULL)
      end
    assert_equal('The fact is nil', error.message)
  end

  def test_refuses_a_nil_fact_with_symbol_prop
    error =
      assert_raises(Fbe::Error) do
        Fbe.who(nil, :author_id, global: {}, options: Judges::Options.new({ 'testing' => true }), loog: Loog::NULL)
      end
    assert_equal('The fact is nil', error.message)
  end

  def test_refuses_a_nil_fact_with_string_prop
    error =
      assert_raises(Fbe::Error) do
        Fbe.who(nil, 'creator', global: {}, options: Judges::Options.new({ 'testing' => true }), loog: Loog::NULL)
      end
    assert_equal('The fact is nil', error.message)
  end

  def test_refuses_a_nil_fact_with_arbitrary_prop
    error =
      assert_raises(Fbe::Error) do
        Fbe.who(nil, :non_existent, global: {}, options: Judges::Options.new({ 'testing' => true }), loog: Loog::NULL)
      end
    assert_equal('The fact is nil', error.message)
  end

  def test_refuses_a_nil_fact_with_no_extra_arguments
    error =
      assert_raises(Fbe::Error) do
        Fbe.who(nil)
      end
    assert_equal('The fact is nil', error.message)
  end

  def test_refuses_a_nil_fact_error_type
    error =
      assert_raises(StandardError) do
        Fbe.who(nil, global: {}, options: Judges::Options.new({ 'testing' => true }), loog: Loog::NULL)
      end
    assert_kind_of(Fbe::Error, error)
  end
end
