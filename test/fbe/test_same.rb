# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/same'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestSame < Fbe::Test
  def test_finds_time_that_is_not_the_first_value
    seed = Random.new_seed
    hour = Random.new(seed).rand(0..20)
    f = Factbase.new.insert
    f.when = Time.utc(2025, 1, 1, hour)
    f.when = Time.utc(2025, 1, 1, hour + 1)
    assert(Fbe.same?(f, { when: Time.utc(2025, 1, 1, hour + 1) }), "second time of the fact is not seen, seed #{seed}")
  end

  def test_refuses_time_that_is_in_no_value
    seed = Random.new_seed
    hour = Random.new(seed).rand(0..20)
    f = Factbase.new.insert
    f.when = Time.utc(2025, 1, 1, hour)
    f.when = Time.utc(2025, 1, 1, hour + 1)
    refute(Fbe.same?(f, { when: Time.utc(2025, 1, 1, hour + 2) }), "absent time is taken as present, seed #{seed}")
  end
end
