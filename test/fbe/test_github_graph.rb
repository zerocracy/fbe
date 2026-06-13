# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/github_graph'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestGitHubGraph < Fbe::Test
  def test_simple_use
    WebMock.disable_net_connect!
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    Fbe.github_graph(options:, loog: Loog::NULL, global:)
  end

  def test_raises_when_graphql_response_carries_errors
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'x')
    errors = Object.new
    errors.define_singleton_method(:empty?) { false }
    errors.define_singleton_method(:messages) { { 'data' => ['Could not resolve to a Repository with the name'] } }
    response = Object.new
    response.define_singleton_method(:errors) { errors }
    response.define_singleton_method(:data) { nil }
    fake_client = Object.new
    fake_client.define_singleton_method(:parse) { |q| q }
    fake_client.define_singleton_method(:query) { |_parsed| response }
    graph.define_singleton_method(:client) { fake_client }
    e = assert_raises(Fbe::Error) { graph.query('{ viewer { login } }') }
    assert_match(/Could not resolve to a Repository/, e.message)
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
      body: JSON.pretty_generate({ data: { repository: { name: 'foo' } } })
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
    result = g.total_commits('zerocracy', 'baza.rb', 'master')
    assert_predicate(result, :positive?)
    g.total_commits(
      repos: [
        %w[zerocracy fbe master],
        %w[zerocracy judges-action master]
      ]
    ).each do |h|
      h = h.transform_keys(&:to_sym)
      assert_pattern do
        h => {
          owner: String,
          name: String,
          branch: String,
          total_commits: 1..
        }
      end
    end
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
    graph.total_commits(
      repos: [
        %w[zerocracy fbe master],
        %w[zerocracy judges-action master]
      ]
    ).each do |h|
      h = h.transform_keys(&:to_sym)
      assert_pattern do
        h => {
          owner: String,
          name: String,
          branch: String,
          total_commits: 1484
        }
      end
    end
  end

  def test_fake_issue_type_event
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    assert_nil(graph.issue_type_event('wrong_id'))
    added = graph.issue_type_event('ITAE_examplevq862Ga8lzwAAAAQZanzv')
    assert_equal('IssueTypeAddedEvent', added['type'])
    assert_equal(Time.parse('2025-05-11 18:17:16 UTC'), added['created_at'])
    assert_equal('Bug', added.dig('issue_type', 'name'))
    assert_nil(added['prev_issue_type'])
    assert_equal(526_301, added.dig('actor', 'id'))
    assert_equal('yegor256', added.dig('actor', 'login'))
    changed = graph.issue_type_event('ITCE_examplevq862Ga8lzwAAAAQZbq9S')
    assert_equal('IssueTypeChangedEvent', changed['type'])
    assert_equal(Time.parse('2025-05-11 20:23:13 UTC'), changed['created_at'])
    assert_equal('Task', changed.dig('issue_type', 'name'))
    assert_equal('Bug', changed.dig('prev_issue_type', 'name'))
    assert_equal(526_301, changed.dig('actor', 'id'))
    assert_equal('yegor256', changed.dig('actor', 'login'))
    removed = graph.issue_type_event('ITRE_examplevq862Ga8lzwAAAAQcqceV')
    assert_equal('IssueTypeRemovedEvent', removed['type'])
    assert_equal(Time.parse('2025-05-11 22:09:42 UTC'), removed['created_at'])
    assert_equal('Feature', removed.dig('issue_type', 'name'))
    assert_nil(removed['prev_issue_type'])
    assert_equal(526_301, removed.dig('actor', 'id'))
    assert_equal('yegor256', removed.dig('actor', 'login'))
  end

  def test_fake_pull_requests_with_reviews
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    h = graph.pull_requests_with_reviews('foo', 'foo', Time.parse('2025-08-01T18:00:00Z'), cursor: nil)
    h = h.transform_keys(&:to_sym)
    assert_pattern do
      h => {
        pulls_with_reviews: Array,
        has_next_page: TrueClass | FalseClass,
        next_cursor: String
      }
    end
  end

  def test_pull_requests_with_reviews_when_repository_is_missing
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'fake')
    graph.define_singleton_method(:query) do |_qry|
      { 'errors' => [{ 'message' => 'Could not resolve to a Repository' }] }
    end
    error =
      assert_raises(Fbe::Error) do
        graph.pull_requests_with_reviews('bad-owner', 'bad-repo', Time.parse('2025-08-01T18:00:00Z'))
      end
    assert_includes(error.message, 'bad-owner/bad-repo')
  end

  def test_fake_pull_request_reviews
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    pulls = graph.pull_request_reviews('foo', 'foo', pulls: [[2, nil], [5, nil], [21, nil]])
    pulls.each do |pull|
      pull = pull.transform_keys(&:to_sym)
      assert_pattern do
        pull => {
          id: String,
          number: Integer,
          reviews: Array,
          reviews_has_next_page: TrueClass | FalseClass,
          reviews_next_cursor: String
        }
      end
    end
  end

  def test_fake_total_commits_pushed
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    h = graph.total_commits_pushed('foo', 'foo', Time.parse('2025-12-11T15:00:00Z'))
    h = h.transform_keys(&:to_sym)
    assert_pattern do
      h => {
        commits: 29,
        hoc: 1857
      }
    end
  end

  def test_fake_total_issues_created
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    h = graph.total_issues_created('foo', 'foo', Time.parse('2025-12-12T15:00:00Z'))
    h = h.transform_keys(&:to_sym)
    assert_pattern do
      h => {
        issues: 17,
        pulls: 8
      }
    end
  end

  def test_fake_total_releases_published
    WebMock.disable_net_connect!
    graph = Fbe.github_graph(options: Judges::Options.new('testing' => true), loog: Loog::NULL, global: {})
    h = graph.total_releases_published('foo', 'foo', Time.parse('2025-12-16T15:00:00Z'))
    h = h.transform_keys(&:to_sym)
    assert_pattern do
      h => {
        releases: 7
      }
    end
  end

  # rubocop:disable Naming/VariableNumber, Elegant/GoodVariableName
  def test_real_total_commits
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      obj = Object.new
      history_mock = Object.new
      history_mock.define_singleton_method(:total_count) { 42 }
      target_mock = Object.new
      target_mock.define_singleton_method(:history) { history_mock }
      ref_obj = Object.new
      ref_obj.define_singleton_method(:target) { target_mock }
      repo_zero = Object.new
      repo_zero.define_singleton_method(:ref) { ref_obj }
      obj.define_singleton_method(:repo_0) { repo_zero }
      obj
    end
    assert_equal(42, graph.total_commits('foo', 'bar', 'main'))
  end

  def test_real_total_commits_raises_when_repo_not_found
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      obj = Object.new
      repo_zero = Object.new
      repo_zero.define_singleton_method(:ref) { nil }
      obj.define_singleton_method(:repo_0) { repo_zero }
      obj
    end
    assert_raises(Fbe::Error) { graph.total_commits('foo', 'bar', 'main') }
  end

  def test_real_total_commits_with_repos_array
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      obj = Object.new
      target_zero = Object.new
      target_zero.define_singleton_method(:history) do
        h = Object.new
        h.define_singleton_method(:total_count) { 10 }
        h
      end
      ref_zero = Object.new
      ref_zero.define_singleton_method(:target) { target_zero }
      repo_zero = Object.new
      repo_zero.define_singleton_method(:ref) { ref_zero }
      obj.define_singleton_method(:repo_0) { repo_zero }
      target_one = Object.new
      target_one.define_singleton_method(:history) do
        h = Object.new
        h.define_singleton_method(:total_count) { 20 }
        h
      end
      ref_one = Object.new
      ref_one.define_singleton_method(:target) { target_one }
      repo_one = Object.new
      repo_one.define_singleton_method(:ref) { ref_one }
      obj.define_singleton_method(:repo_1) { repo_one }
      obj
    end
    result = graph.total_commits(repos: [%w[foo bar main], %w[baz qux master]])
    assert_equal(2, result.size)
    assert_equal(10, result[0]['total_commits'])
    assert_equal(20, result[1]['total_commits'])
  end
  # rubocop:enable Naming/VariableNumber, Elegant/GoodVariableName

  def test_real_total_issues_and_pulls
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      { 'repository' => { 'issues' => { 'totalCount' => 7 }, 'pullRequests' => { 'totalCount' => 3 } } }
    end
    result = graph.total_issues_and_pulls('foo', 'bar')
    assert_equal(7, result['issues'])
    assert_equal(3, result['pulls'])
  end

  def test_real_total_issues_and_pulls_defaults_to_zero
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      { 'repository' => {} }
    end
    result = graph.total_issues_and_pulls('foo', 'bar')
    assert_equal(0, result['issues'])
    assert_equal(0, result['pulls'])
  end

  def test_real_resolved_conversations
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      {
        'repository' => {
          'pullRequest' => {
            'reviewThreads' => {
              'nodes' => [
                { 'id' => 't1', 'isResolved' => true, 'comments' => { 'nodes' => [] } },
                { 'id' => 't2', 'isResolved' => false, 'comments' => { 'nodes' => [] } }
              ]
            }
          }
        }
      }
    end
    result = graph.resolved_conversations('foo', 'bar', 42)
    assert_equal(1, result.size)
    assert_equal('t1', result[0]['id'])
  end

  def test_real_resolved_conversations_returns_empty_when_no_nodes
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      { 'repository' => { 'pullRequest' => { 'reviewThreads' => { 'nodes' => nil } } } }
    end
    assert_empty(graph.resolved_conversations('foo', 'bar', 42))
  end

  def test_real_issue_type_event_added
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      {
        'node' => {
          '__typename' => 'IssueTypeAddedEvent',
          'createdAt' => '2025-05-11T18:17:16Z',
          'issueType' => { 'id' => 'it1', 'name' => 'Bug', 'description' => 'A bug' },
          'actor' => {
            '__typename' => 'User',
            'login' => 'yegor256',
            'databaseId' => 526_301,
            'name' => 'Yegor',
            'email' => 'yegor@test.com'
          }
        }
      }
    end
    result = graph.issue_type_event('some_id')
    assert_equal('IssueTypeAddedEvent', result['type'])
    assert_equal('Bug', result.dig('issue_type', 'name'))
    assert_nil(result['prev_issue_type'])
  end

  def test_real_issue_type_event_changed
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      {
        'node' => {
          '__typename' => 'IssueTypeChangedEvent',
          'createdAt' => '2025-05-11T20:23:13Z',
          'issueType' => { 'id' => 'it2', 'name' => 'Task', 'description' => 'A task' },
          'prevIssueType' => { 'id' => 'it1', 'name' => 'Bug', 'description' => 'A bug' },
          'actor' => {
            '__typename' => 'User',
            'login' => 'yegor256',
            'databaseId' => 526_301,
            'name' => 'Yegor',
            'email' => 'yegor@test.com'
          }
        }
      }
    end
    result = graph.issue_type_event('some_id')
    assert_equal('IssueTypeChangedEvent', result['type'])
    assert_equal('Task', result.dig('issue_type', 'name'))
    assert_equal('Bug', result.dig('prev_issue_type', 'name'))
  end

  def test_real_issue_type_event_returns_nil_for_unknown
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      { 'node' => nil }
    end
    assert_nil(graph.issue_type_event('unknown'))
  end

  def test_real_total_commits_pushed
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      {
        'repository' => {
          'defaultBranchRef' => {
            'target' => {
              'history' => {
                'totalCount' => 5,
                'nodes' => [
                  { 'oid' => 'abc', 'parents' => { 'totalCount' => 1 }, 'additions' => 100, 'deletions' => 10 },
                  { 'oid' => 'def', 'parents' => { 'totalCount' => 2 }, 'additions' => 50, 'deletions' => 5 }
                ],
                'pageInfo' => { 'endCursor' => nil, 'hasNextPage' => false }
              }
            }
          }
        }
      }
    end
    result = graph.total_commits_pushed('foo', 'bar', Time.parse('2025-01-01'))
    assert_equal(5, result['commits'])
    assert_equal(165, result['hoc'])
  end

  def test_real_total_issues_created
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      { 'issues' => { 'issueCount' => 10 }, 'pulls' => { 'issueCount' => 3 } }
    end
    result = graph.total_issues_created('foo', 'bar', Time.parse('2025-01-01'))
    assert_equal(10, result['issues'])
    assert_equal(3, result['pulls'])
  end

  def test_real_total_issues_created_defaults_to_zero
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      {}
    end
    result = graph.total_issues_created('foo', 'bar', Time.parse('2025-01-01'))
    assert_equal(0, result['issues'])
    assert_equal(0, result['pulls'])
  end

  def test_real_total_releases_published
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    calls = 0
    graph.define_singleton_method(:query) do |_qry|
      calls += 1
      {
        'repository' => {
          'releases' => {
            'nodes' => [
              { 'isDraft' => false, 'publishedAt' => '2025-06-01T00:00:00Z' },
              { 'isDraft' => true, 'publishedAt' => '2025-06-01T00:00:00Z' },
              { 'isDraft' => false, 'publishedAt' => '2024-01-01T00:00:00Z' }
            ],
            'pageInfo' => { 'endCursor' => nil, 'hasNextPage' => false }
          }
        }
      }
    end
    result = graph.total_releases_published('foo', 'bar', Time.parse('2025-01-01'))
    assert_equal(1, result['releases'])
    assert_equal(1, calls)
  end

  def test_real_pull_requests_with_reviews
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      {
        'repository' => {
          'pullRequests' => {
            'nodes' => [
              {
                'id' => 'PR_1',
                'number' => 1,
                'timelineItems' => { 'nodes' => [{ 'id' => 'rev_1' }] }
              },
              {
                'id' => 'PR_2',
                'number' => 2,
                'timelineItems' => { 'nodes' => [] }
              }
            ],
            'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
          }
        }
      }
    end
    result = graph.pull_requests_with_reviews('foo', 'bar', Time.parse('2025-08-01T18:00:00Z'))
    assert_equal(1, result['pulls_with_reviews'].size)
    assert_equal(1, result['pulls_with_reviews'][0]['number'])
    refute(result['has_next_page'])
    assert_nil(result['next_cursor'])
  end

  def test_real_pull_request_reviews
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'test')
    graph.define_singleton_method(:query) do |_qry|
      {
        'repository' => {
          'pr_2' => {
            'id' => 'PR_2',
            'number' => 2,
            'reviews' => {
              'nodes' => [
                { 'id' => 'rev_1', 'submittedAt' => '2025-10-02T12:58:42Z' }
              ],
              'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
            }
          }
        }
      }
    end
    pulls = graph.pull_request_reviews('foo', 'bar', pulls: [[2, nil]])
    assert_equal(1, pulls.size)
    assert_equal(2, pulls[0]['number'])
    assert_equal(1, pulls[0]['reviews'].size)
  end

  def test_real_pull_request_reviews_omits_after_when_cursor_is_nil
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'fake')
    captured = nil
    page = { 'nodes' => [], 'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil } }
    graph.define_singleton_method(:query) do |qry|
      captured = qry
      { 'repository' => { 'pullRequests' => page } }
    end
    graph.pull_requests_with_reviews('foo', 'bar', Time.parse('2025-08-01T18:00:00Z'), cursor: nil)
    refute_includes(captured, 'after: ""')
  end

  def test_pull_request_reviews_omits_after_when_cursor_is_nil
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'fake')
    captured = nil
    reviews = { 'nodes' => [], 'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil } }
    graph.define_singleton_method(:query) do |qry|
      captured = qry
      { 'repository' => { 'pr_2' => { 'id' => 'PR_x', 'number' => 2, 'reviews' => reviews } } }
    end
    graph.pull_request_reviews('foo', 'bar', pulls: [[2, nil]])
    refute_includes(captured, 'after: ""')
  end

  def test_total_releases_published_omits_after_when_cursor_is_nil
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'fake')
    captured = nil
    page = { 'nodes' => [], 'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil } }
    graph.define_singleton_method(:query) do |qry|
      captured = qry
      { 'repository' => { 'releases' => page } }
    end
    graph.total_releases_published('foo', 'bar', Time.parse('2025-08-01T18:00:00Z'))
    refute_includes(captured, 'after: ""')
  end
end
