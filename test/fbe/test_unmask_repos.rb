# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'judges/options'
require 'loog'
require_relative '../test__helper'
require_relative '../../lib/fbe/unmask_repos'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestUnmaskRepos < Minitest::Test
  def test_simple_use
    opts = Judges::Options.new(
      {
        'testing' => true,
        'repositories' => 'yegor256/tacit,zerocracy/*,-zerocracy/judges-action,zerocracy/datum'
      }
    )
    list = Fbe.unmask_repos(options: opts, global: {}, loog: Loog::NULL)
    assert_predicate(list.size, :positive?)
    refute_includes(list, 'zerocracy/datum')
  end

  def test_live_usage
    skip('Run it only manually, since it touches GitHub API')
    opts = Judges::Options.new(
      {
        'repositories' => 'zerocracy/*,-zerocracy/judges-action,zerocracy/datum'
      }
    )
    list = Fbe.unmask_repos(options: opts, global: {}, loog: Loog::NULL)
    assert_predicate(list.size, :positive?)
    assert_includes(list, 'zerocracy/pages-action')
    refute_includes(list, 'zerocracy/judges-action')
    refute_includes(list, 'zerocracy/datum')
  end
end
