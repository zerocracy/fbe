# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestFakeOctokit < Fbe::Test
  # These run in a child process on purpose. The suite loads the whole gem
  # through `test__helper`, so in-process the constants are already there and
  # nothing here could fail. The bug is about requiring this file ALONE, which
  # only a clean process can show.
  def test_stands_on_its_own
    stdout, stderr, status =
      Open3.capture3(
        'ruby', '-I', File.expand_path('../../lib', __dir__), '-e',
        "require 'fbe/fake_octokit'; print Fbe::FakeOctokit.new.rate_limit.remaining"
      )
    assert_predicate(status, :success?, "Requiring the file on its own failed: #{stderr}")
    assert_equal('100', stdout)
  end

  def test_raises_not_found_on_its_own
    _, stderr, status =
      Open3.capture3(
        'ruby', '-I', File.expand_path('../../lib', __dir__), '-e',
        "require 'fbe/fake_octokit'; " \
        "begin; Fbe::FakeOctokit.new.user(404_001); rescue Octokit::NotFound; print 'ok'; end"
      )
    assert_predicate(status, :success?, "Octokit was not reachable on its own: #{stderr}")
  end
end
