# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/fb'
require_relative '../../lib/fbe/kill_if'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestKillIf < Fbe::Test
  def test_deletes_a_few
    fb = Factbase.new
    f = fb.insert
    f.foo = 42
    f.hey = 4
    f.id = 555
    Fbe.kill_if([f], fb:, fid: 'id')
    assert_equal(0, fb.size)
  end

  def test_deletes_with_a_block
    fb = Factbase.new
    fb.insert.then do |f|
      f.foo = 0
      f._id = 777
    end
    fb.insert.then do |f|
      f.foo = 1
      f._id = 778
    end
    assert_equal(1, Fbe.kill_if(fb.query('(always)').each.to_a, fb:) { |f| f.foo.zero? })
    assert_equal(1, fb.size)
  end

  def test_deletes_multiple_facts
    fb = Factbase.new
    fb.insert.then { |f| f._id = 10 }
    fb.insert.then { |f| f._id = 20 }
    fb.insert.then { |f| f._id = 30 }
    facts = fb.query('(always)').each.to_a
    assert_equal(2, Fbe.kill_if([facts[0], facts[2]], fb:))
    assert_equal(1, fb.size)
  end

  def test_returns_zero_when_facts_empty
    fb = Factbase.new
    assert_equal(0, Fbe.kill_if([], fb:))
  end

  def test_returns_zero_when_block_rejects_all
    fb = Factbase.new
    fb.insert.foo = 1
    fb.insert.foo = 2
    assert_equal(0, Fbe.kill_if(fb.query('(always)').each.to_a, fb:) { false })
    assert_equal(2, fb.size)
  end
end
