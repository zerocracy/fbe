# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/github_graph'
require_relative '../test__helper'

# Only read operations may be retried after a transient transport failure.
class TestGraphRetries < Fbe::Test
  def setup
    WebMock.reset!
    WebMock.disable_net_connect!
  end

  def test_retries_server_errors_then_returns_data
    [500, 502, 503, 504, 599].each do |status|
      WebMock.reset!
      stub_request(:post, endpoint).to_return(status:, body: 'unavailable').then.to_return(status: 200, body: success)
      assert_equal('octocat', graph.query('{ viewer { login } }').viewer.login)
      assert_requested(:post, endpoint, times: 2)
    end
  end

  def test_preserves_last_server_error_after_four_retries
    stub_request(:post, endpoint).to_return(status: 502, body: 'gateway').times(4)
      .then.to_return(status: 503, body: 'unavailable')
    assert_match(/503/, assert_raises(Fbe::Error) { graph.query('{ viewer { login } }') }.message)
    assert_requested(:post, endpoint, times: 5)
  end

  def test_retries_network_timeouts
    [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout].each do |error|
      WebMock.reset!
      stub_request(:post, endpoint).to_raise(error.new('temporary timeout')).then.to_return(status: 200, body: success)
      assert_equal('octocat', graph.query('{ viewer { login } }').viewer.login)
      assert_requested(:post, endpoint, times: 2)
    end
  end

  def test_preserves_timeout_after_four_retries
    error = Net::ReadTimeout.new('last timeout')
    stub_request(:post, endpoint).to_raise(Net::ReadTimeout.new('first timeout')).times(4).then.to_raise(error)
    assert_same(error, assert_raises(Net::ReadTimeout) { graph.query('{ viewer { login } }') })
    assert_requested(:post, endpoint, times: 5)
  end

  def test_does_not_retry_client_or_graphql_errors
    [200, 400, 401, 403, 404, 429].each do |status|
      WebMock.reset!
      stub_request(:post, endpoint).to_return(status:, body: { errors: [{ message: 'denied' }] }.to_json)
      assert_raises(Fbe::Error) { graph.query('{ viewer { login } }') }
      assert_requested(:post, endpoint, times: 1)
    end
  end

  def test_does_not_retry_mutations_after_server_errors
    [
      ['mutation { update { login } }', nil],
      ['query Read { viewer { login } } mutation Write { update { login } }', 'Write']
    ].each do |query, name|
      WebMock.reset!
      stub_request(:post, endpoint).to_return(status: 502, body: 'gateway')
      result = transport.execute(document: GraphQL.parse(query), operation_name: name)
      assert_match(/502/, result.fetch('errors').first.fetch('message'))
      assert_requested(:post, endpoint, times: 1)
    end
  end

  def test_does_not_retry_mutations_after_timeout
    stub_request(:post, endpoint).to_raise(Net::ReadTimeout.new('ambiguous outcome'))
    assert_raises(Net::ReadTimeout) { graph.query('mutation { update { login } }') }
    assert_requested(:post, endpoint, times: 1)
  end

  def test_retries_only_the_selected_named_query_with_unchanged_payload
    query = 'query Read($name: String) { viewer(name: $name) { login } } mutation Write { update { login } }'
    document = GraphQL.parse(query)
    stub_request(:post, endpoint).with(
      body: { query: document.to_query_string, operationName: 'Read', variables: { name: 'octocat' } },
      headers: { 'Authorization' => 'Bearer fake' }
    ).to_return(status: 503, body: 'unavailable').then.to_return(status: 200, body: success)
    result = transport.execute(document:, operation_name: 'Read', variables: { name: 'octocat' })
    assert_equal('octocat', result.dig('data', 'viewer', 'login'))
    assert_requested(:post, endpoint, times: 2)
  end

  def test_does_not_retry_an_ambiguous_operation
    query = 'query One { viewer { login } } query Two { viewer { login } }'
    stub_request(:post, endpoint).to_return(status: 503, body: 'unavailable')
    transport.execute(document: GraphQL.parse(query))
    assert_requested(:post, endpoint, times: 1)
  end

  def test_retries_schema_introspection
    payload = schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY).to_json
    stub_request(:post, endpoint).to_return(status: 502, body: 'gateway').then.to_return(status: 200, body: payload)
    dump = GraphQL::Client.dump_schema(transport)
    assert_equal('Query', dump.dig('data', '__schema', 'queryType', 'name'))
    assert_requested(:post, endpoint, times: 2)
  end

  private

  def endpoint
    'https://api.github.com/graphql'
  end

  def success
    { data: { viewer: { login: 'octocat' } } }.to_json
  end

  def schema
    GraphQL::Schema.from_definition(
      'type Query { viewer(name: String): User } type User { login: String } type Mutation { update: User }'
    )
  end

  def transport
    Fbe::Graph::HTTP.new('fake', 'api.github.com')
  end

  def graph
    client = GraphQL::Client.new(schema:, execute: transport)
    client.allow_dynamic_queries = true
    Fbe::Graph.new(token: 'fake').tap do |instance|
      instance.define_singleton_method(:client) { client }
    end
  end
end
