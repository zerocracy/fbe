# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/award'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestAwardLogic < Fbe::Test
  def test_formats_the_operands_of_and
    assert_includes(
      Fbe::Award.new('(award (in a "A") (in b "B") (give (if (and a b) 1 0) "t"))').bylaw.markdown,
      'if _a_ and _b_ then'
    )
  end

  def test_formats_the_operand_of_not
    assert_includes(
      Fbe::Award.new('(award (in a "A") (give (if (not a) 1 0) "t"))').bylaw.markdown,
      'if not _a_ then'
    )
  end
end
