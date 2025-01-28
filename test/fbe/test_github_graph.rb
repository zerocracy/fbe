# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024-2025 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require 'judges/options'
require 'webmock/minitest'
require 'loog'
require_relative '../../lib/fbe/github_graph'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestGitHubGraph < Minitest::Test
  def test_simple_use
    WebMock.disable_net_connect!
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    Fbe.github_graph(options:, loog: Loog::NULL, global:)
  end

  def test_simple_use_graph
    skip("it's a live test, run it manually if you need it")
    WebMock.allow_net_connect!
    client = Fbe::Graph.new(token: ENV.fetch('GITHUB_TOKEN', nil))
    result = client.query(
      <<~GRAPHQL
        query {
          viewer {
              login
          }
        }
      GRAPHQL
    )
    refute_empty(result.viewer.login)
  end

  def test_use_with_global_variables
    WebMock.disable_net_connect!
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    Fbe.github_graph
  end

  def test_with_broken_token
    skip("it's a live test, run it manually if you need it")
    WebMock.allow_net_connect!
    global = {}
    options = Judges::Options.new({ 'github_token' => 'incorrect-value' })
    assert_raises(StandardError) { Fbe.github_graph(loog: Loog::NULL, global:, options:) }
  end

  def test_gets_resolved_conversations
    skip("it's a live test, run it manually if you need it")
    WebMock.allow_net_connect!
    global = {}
    options = Judges::Options.new
    g = Fbe.github_graph(options:, loog: Loog::NULL, global:)
    result = g.resolved_conversations('zerocracy', 'baza', 172)
    assert_equal(1, result.count)
    result = g.resolved_conversations('zerocracy', 'baza', 0)
    assert_instance_of(Array, result)
    assert_equal(0, result.count)
    result = g.resolved_conversations('zerocracy1', 'baza', 0)
    assert_instance_of(Array, result)
    assert_equal(0, result.count)
    result = g.resolved_conversations('zerocracy', 'baza1', 0)
    assert_instance_of(Array, result)
    assert_equal(0, result.count)
  end

  def test_does_not_count_unresolved_conversations
    skip("it's a live test, run it manually if you need it")
    WebMock.allow_net_connect!
    g = Fbe.github_graph(options: Judges::Options.new, loog: Loog::NULL, global: {})
    result = g.resolved_conversations('zerocracy', 'judges-action', 296)
    assert_equal(0, result.count)
  end

  def test_gets_total_commits_of_repo
    skip("it's a live test, run it manually if you need it")
    WebMock.allow_net_connect!
    global = {}
    options = Judges::Options.new
    g = Fbe.github_graph(options:, loog: Loog::NULL, global:)
    result = g.total_commits('zerocracy', 'baza', 'master')
    assert_predicate(result, :positive?)
  end

  def test_get_fake_empty_conversations
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    result = graph.resolved_conversations(nil, 'baza', 172)
    assert_empty(result)
  end

  def test_get_fake_conversations
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    result = graph.resolved_conversations('zerocracy', 'baza', 172)
    assert_equal(1, result.count)
  end

  def test_total_issues_and_pulls
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    result = graph.total_issues_and_pulls('zerocracy', 'fbe')
    refute_empty(result)
    assert_equal(23, result['issues'])
    assert_equal(19, result['pulls'])
  end

  def test_fake_total_commits
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    assert_equal(1484, graph.total_commits('zerocracy', 'fbe', 'master'))
  end
end
