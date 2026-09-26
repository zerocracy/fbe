# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/github_graph'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestGitHubGraphNumber < Fbe::Test
  def test_refuses_text_as_pull_request_number
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'x')
    e =
      assert_raises(Fbe::Error) do
        graph.resolved_conversations('foo', 'bar', '1) { id } injected: repository(owner: "x", name: "y") { id } #')
      end
    assert_match(/must be an Integer/, e.message)
  end

  def test_refuses_text_as_pull_request_number_in_reviews
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'x')
    assert_raises(Fbe::Error) { graph.pull_request_reviews('foo', 'bar', pulls: [['42) { id } #', nil]]) }
  end
end
