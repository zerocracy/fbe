# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/term'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestTerm < Fbe::Test
  def test_cannot_spell_infinity
    seed = Random.new_seed
    rnd = Random.new(seed)
    assert_raises(Fbe::Error, "an infinity was spelled in a term, seed #{seed}") do
      Fbe::Term.new("pä#{rnd.rand(1000)}", Float::INFINITY * [1, -1].sample(random: rnd)).to_s
    end
  end
end
