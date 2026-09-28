# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/delete_one'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestDeleteOneDuplicate < Fbe::Test
  def test_keeps_the_other_copy_of_the_value
    fb = Factbase.new
    f = fb.insert
    f._id = 1
    f.what = 'dup'
    f.tags = 'x'
    f.tags = 'y'
    f.tags = 'x'
    Fbe.delete_one(f, 'tags', 'x', fb:)
    assert_equal(%w[y x], fb.query("(eq what 'dup')").each.first['tags'])
  end
end
