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
end
