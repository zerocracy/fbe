# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/award'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestAwardSet < Fbe::Test
  def test_resolves_a_set_variable_in_the_text
    md = Fbe::Award.new('(award (aka (set fee 5) (give fee "as a basis") "deduct ${fee} points"))').bylaw.markdown
    assert_includes(md, 'deduct **5** points', md)
  end
end
