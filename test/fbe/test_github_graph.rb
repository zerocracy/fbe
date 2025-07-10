# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock/minitest'
require_relative '../../lib/fbe/github_graph'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestGitHubGraph < Fbe::Test
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

  def test_gets_resolved_conversations_via_http
    skip('This test does not work, because the JSON returned is not a valid response from GraphQL')
    WebMock.disallow_net_connect!
    global = {}
    options = Judges::Options.new
    g = Fbe.github_graph(options:, loog: Loog::NULL, global:)
    stub_request(:post, 'https://api.github.com/graphql').to_return(
      body: JSON.pretty_generate(
        {
          data: {
            repository: {
              name: 'foo'
            }
          }
        }
      )
    )
    result = g.resolved_conversations('foo', 'bar', 42)
    assert_equal(1, result.count)
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

  def test_fake_issue_type_event
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    assert_nil(graph.issue_type_event('wrong_id'))
    add_type_event = graph.issue_type_event('ITAE_examplevq862Ga8lzwAAAAQZanzv')
    assert_equal('IssueTypeAddedEvent', add_type_event['type'])
    assert_equal(Time.parse('2025-05-11 18:17:16 UTC'), add_type_event['created_at'])
    assert_equal('Bug', add_type_event.dig('issue_type', 'name'))
    assert_nil(add_type_event['prev_issue_type'])
    assert_equal(526_301, add_type_event.dig('actor', 'id'))
    assert_equal('yegor256', add_type_event.dig('actor', 'login'))
    change_type_event = graph.issue_type_event('ITCE_examplevq862Ga8lzwAAAAQZbq9S')
    assert_equal('IssueTypeChangedEvent', change_type_event['type'])
    assert_equal(Time.parse('2025-05-11 20:23:13 UTC'), change_type_event['created_at'])
    assert_equal('Task', change_type_event.dig('issue_type', 'name'))
    assert_equal('Bug', change_type_event.dig('prev_issue_type', 'name'))
    assert_equal(526_301, change_type_event.dig('actor', 'id'))
    assert_equal('yegor256', change_type_event.dig('actor', 'login'))
    remove_type_event = graph.issue_type_event('ITRE_examplevq862Ga8lzwAAAAQcqceV')
    assert_equal('IssueTypeRemovedEvent', remove_type_event['type'])
    assert_equal(Time.parse('2025-05-11 22:09:42 UTC'), remove_type_event['created_at'])
    assert_equal('Feature', remove_type_event.dig('issue_type', 'name'))
    assert_nil(remove_type_event['prev_issue_type'])
    assert_equal(526_301, remove_type_event.dig('actor', 'id'))
    assert_equal('yegor256', remove_type_event.dig('actor', 'login'))
  end
end
