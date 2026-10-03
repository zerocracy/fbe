# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require 'rbconfig'
require_relative '../test__helper'

# Test.
class TestFakeOctokit < Fbe::Test
  def test_can_be_required_on_its_own
    script = <<~'RUBY'
      require 'fbe/fake_octokit'
      fake = Fbe::FakeOctokit.new
      abort unless fake.rate_limit.remaining == 100
      begin
        fake.user(404_001)
      rescue Octokit::NotFound
        exit
      end
      abort 'expected a not-found response'
    RUBY
    _, stderr, status = Open3.capture3(
      RbConfig.ruby,
      "-I#{File.expand_path('../../lib', __dir__)}",
      '-e',
      script
    )
    assert(status.success?, stderr)
  end
end
