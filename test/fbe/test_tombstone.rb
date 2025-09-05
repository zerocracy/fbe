# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/tombstone'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestTombstone < Fbe::Test
  def test_simple
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    ts.bury!(where, 41, 13)
    ts.bury!(where, 42, 13)
    ts.bury!(where, 42, 999)
    assert(ts.has?(where, 41, 13))
    assert(ts.has?(where, 42, 999))
    refute(ts.has?(where, 8, 7))
    refute(ts.has?(where, 43, 999))
    refute(ts.has?(where, 43, 990))
  end

  def test_on_empty
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    refute(ts.has?(where, 8, 7))
  end

  def test_bury_twice
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    2.times { ts.bury!(where, 42, 7) }
    assert(ts.has?(where, 42, 7))
  end

  def test_merges_them
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    ts.bury!(where, 42, 13)
    ts.bury!(where, 42, 18)
    ts.bury!(where, 42, 14)
    ts.bury!(where, 42, [17, 15, 16])
    assert(ts.has?(where, 42, 16))
    assert(ts.has?(where, 42, [16, 18]))
    refute(ts.has?(where, 42, 22))
  end

  def test_merge_complex_ranges
    where = 'github'
    repo = 42
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.what = 'tombstone'
      f.where = where
      f.repo = repo
      Fbe.overwrite(f, 'issues', %w[4-4 4-5 5-6 5-5 4-6 10-14], fb:)
    end
    ts = Fbe::Tombstone.new(fb:)
    ts.bury!(where, repo, 5)
    f = fb.query('(always)').each.to_a.first
    assert_equal(%w[4-6 10-14], f['issues'])
    Fbe.overwrite(f, 'issues', %w[14-15 8-8 4-5 4-4 5-6 5-5 4-6 10-13], fb:)
    ts.bury!(where, repo, 20)
    assert_equal(%w[4-6 8-8 10-15 20-20], fb.query('(always)').each.to_a.first['issues'])
  end
end
