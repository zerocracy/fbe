# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/octo'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestOctoRespond < Fbe::Test
  def test_denies_a_method_it_does_not_have
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new(['testing=true']))
    refute_respond_to(o, :no_such_method)
    assert_respond_to(o, :repository)
    assert_respond_to(o, :off_quota?)
  end
end
