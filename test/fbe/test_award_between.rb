# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/award'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestAwardBetween < Fbe::Test
  def test_describes_negative_bounds_by_absolute_value
    md = Fbe::Award.new('(award (in x "the value") (give (between x -4 -16) "for x"))').bylaw.markdown
    assert_includes(md, 'clamped by absolute value between **-4** and **-16**', md)
    assert_includes(md, 'or 0 if its absolute value is smaller than both', md)
  end
end
