# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require_relative '../../lib/fbe/unmask_repos'
require_relative '../test__helper'

class TestUnmaskBudgets < Fbe::Test
  def test_honors_the_quota_by_default
    options = Judges::Options.new({ 'testing' => true, 'repositories' => 'foo/bar' })
    client = Fbe.octo(options:, global: {}, loog: Loog::NULL)
    yielded = []
    client.stub(:off_quota?, true) do
      Fbe.stub(:octo, client) do
        Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL) { |repo| yielded << repo }
      end
    end
    assert_empty(yielded)
  end

  def test_honors_the_lifetime_by_default
    options = Judges::Options.new({ 'testing' => true, 'repositories' => 'foo/bar', 'lifetime' => 1 })
    yielded = []
    Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL, epoch: Time.now - 10) { |repo| yielded << repo }
    assert_empty(yielded)
  end

  def test_honors_the_timeout_by_default
    options = Judges::Options.new({ 'testing' => true, 'repositories' => 'foo/bar', 'timeout' => 1 })
    yielded = []
    Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL, kickoff: Time.now - 10) { |repo| yielded << repo }
    assert_empty(yielded)
  end

  def test_returns_the_list_after_the_lifetime_without_a_block
    options = Judges::Options.new({ 'testing' => true, 'repositories' => 'foo/bar', 'lifetime' => 1 })
    list = Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL, epoch: Time.now - 10)
    assert_equal(['foo/bar'], list)
  end
end
