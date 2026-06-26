# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/sec'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestSec < Fbe::Test
  def test_simple
    fb = Factbase.new
    f = fb.insert
    f.seconds = 333
    assert(Fbe.sec(f).start_with?('5m'))
  end

  def test_formats_elapsed_time_for_a_week
    fb = Factbase.new
    f = fb.insert
    f.seconds = 86_400 * 7
    assert_equal('1w', Fbe.sec(f))
  end

  def test_uses_custom_property
    fb = Factbase.new
    f = fb.insert
    f.duration = 86_400 * 30
    assert_equal('1mo', Fbe.sec(f, :duration))
  end

  def test_elapsed_past
    fb = Factbase.new
    f = fb.insert
    f.seconds = 7200
    now = Time.now
    Time.stub(:now, now) do
      assert_equal('2h', Fbe.sec(f))
    end
  end
end
