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

  def test_rejects_duplicate_ids_without_dropping_facts
    fb = Factbase.new
    first = fb.insert
    first._id = 1
    first.what = 'first'
    first.tags = 'old'
    first.tags = 'keep'
    second = fb.insert
    second._id = 1
    second.what = 'second'
    second.tags = 'old'
    second.tags = 'keep'

    error = assert_raises(Fbe::Error) { Fbe.delete_one(first, 'tags', 'old', fb:) }

    assert_match(/2 facts share _id = 1/, error.message)
    assert_equal(%w[old keep], fb.query("(eq what 'first')").each.first['tags'])
    assert_equal(%w[old keep], fb.query("(eq what 'second')").each.first['tags'])
  end
end
