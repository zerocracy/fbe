# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require_relative '../../lib/fbe/if_absent'
require_relative '../../lib/fbe/just_one'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestIfAbsentArray < Fbe::Test
  def test_refuses_an_array_in_if_absent
    $loog = Loog::NULL
    fb = Factbase.new
    e =
      assert_raises(Fbe::Error) do
        Fbe.if_absent(fb:) do |f|
          f.what = 'arr'
          f.tags = [1, 2, 3]
        end
      end
    assert_match(/only by one value/, e.message)
  end

  def test_refuses_an_array_in_just_one
    $loog = Loog::NULL
    fb = Factbase.new
    assert_raises(Fbe::Error) do
      Fbe.just_one(fb:) do |f|
        f.what = 'arr'
        f.tags = [1, 2, 3]
      end
    end
  end
end
