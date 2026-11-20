# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'time'
require_relative '../../lib/fbe/term'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestTerm < Fbe::Test
  def test_matches_a_string_with_quotes_and_umlauts
    seed = Random.new_seed
    name = "über'\"#{Random.new(seed).rand(1 << 32).to_s(36)}"
    fb = Factbase.new
    fb.insert.then { |f| f.name = name }
    assert_equal(1, fb.query(Fbe::Term.new('name', name).to_s).each.to_a.size, "not matched, seed: #{seed}")
  end

  def test_matches_a_time
    stamp = Time.parse('2024-03-04T05:06:07Z')
    fb = Factbase.new
    fb.insert.then { |f| f.when = stamp }
    assert_equal(1, fb.query(Fbe::Term.new('when', stamp).to_s).each.to_a.size, 'the rendered time matches nothing')
  end
end
