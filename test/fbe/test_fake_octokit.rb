# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/fake_octokit'
require_relative '../test__helper'

# Test.
class TestFakeOctokit < Fbe::Test
  def test_rate_limit_when_required_directly
    assert_equal(100, Fbe::FakeOctokit.new.rate_limit.remaining)
  end
end
