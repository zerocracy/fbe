# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require 'factbase'
require 'judges/options'
require_relative '../test__helper'
require_relative '../../lib/fbe/iterate'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestIterate < Minitest::Test
  def test_simple
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Factbase.new
    fb.insert.foo = 42
    Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global: {}) do
      as 'labels-were-scanned'
      by '(agg (always) (max foo))'
      repeats 2
      over do |_repository, foo|
        f = fb.insert
        f.foo = foo + 1
        f.foo
      end
    end
    assert_equal(4, fb.size)
  end

  def test_many_repeats
    opts = Judges::Options.new(['repositories=foo/bar,foo/second', 'testing=true'])
    cycles = 0
    reps = 5
    Fbe.iterate(fb: Factbase.new, loog: Loog::NULL, global: {}, options: opts) do
      as 'labels-were-scanned'
      by '(plus 1 1)'
      repeats reps
      over do |_, nxt|
        cycles += 1
        nxt
      end
    end
    assert_equal(reps * 2, cycles)
  end

  def test_with_restart
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    cycles = 0
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts) do
      as 'labels-were-scanned'
      by '(agg (and (eq foo 42) (not (exists bar))) (max foo))'
      repeats 10
      over do |_, nxt|
        cycles += 1
        f.bar = 1
        nxt
      end
    end
    assert_equal(1, cycles)
  end
end
