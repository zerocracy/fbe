# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require_relative '../../../lib/fbe/middleware/rate_limit'
require_relative '../../test__helper'

class RateLimitUsedTest < Fbe::Test
  def test_updates_both_resources_and_preserves_the_original_response
    [true, false].each do |json|
      conn = connection(json:)
      original = conn.get('/rate_limit')
      conn.get('/user')
      conn.get('/search/issues')
      response = conn.get('/rate_limit')
      body = json ? response.body : JSON.parse(response.body)
      before = json ? original.body : JSON.parse(original.body)
      assert_equal(
        [2, 2, 1], [body['rate']['used'], body['resources']['core']['used'], body['resources']['search']['used']]
      )
      assert_equal(%w[2 4998], [response.headers['x-ratelimit-used'], response.headers['x-ratelimit-remaining']])
      assert_equal(1, before['rate']['used'])
    end
  end

  def test_ignores_usage_headers_from_http_cache
    conn = connection
    conn.get('/rate_limit')
    conn.get('/user')
    conn.get('/cached')
    body = conn.get('/rate_limit').body
    assert_equal([2, 4997], [body['rate']['used'], body['rate']['remaining']])
  end

  def test_updates_usage_without_a_remaining_header
    conn = connection
    conn.get('/rate_limit')
    conn.get('/used-only')
    response = conn.get('/rate_limit')
    assert_equal(
      [7, '7', 4998],
      [response.body['rate']['used'], response.headers['x-ratelimit-used'], response.body['rate']['remaining']]
    )
  end

  def test_preserves_missing_usage_counters
    conn = connection(initial: nil)
    conn.get('/rate_limit')
    response = conn.get('/rate_limit')
    body = response.body
    assert_equal(
      [false, false, false, false],
      [
        body['rate'].key?('used'), body['resources']['core'].key?('used'),
        body['resources']['search'].key?('used'), response.headers.key?('x-ratelimit-used')
      ]
    )
  end

  def test_preserves_zero_usage
    conn = connection(initial: 0)
    conn.get('/rate_limit')
    response = conn.get('/rate_limit')
    assert_equal([0, '0'], [response.body['rate']['used'], response.headers['x-ratelimit-used']])
  end

  private

  def connection(json: true, initial: 1)
    core = { limit: 5000, remaining: 5000 - (initial || 0) }
    search = { limit: 30, remaining: 30 }
    unless initial.nil?
      core[:used] = initial
      search[:used] = 0
    end
    headers = { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => core[:remaining].to_s }
    headers['X-RateLimit-Used'] = initial.to_s unless initial.nil?
    payload = { rate: core, resources: { core:, search: } }
    Faraday.new('https://api.github.com') do |client|
      client.use(Fbe::Middleware::RateLimit)
      client.response(:json) if json
      client.adapter(:test) do |stubs|
        stubs.get('/rate_limit') { [200, headers, payload.to_json] }
        stubs.get('/user') { [200, { 'X-RateLimit-Used' => '2', 'X-RateLimit-Remaining' => '4998' }, '{}'] }
        stubs.get('/search/issues') { [200, { 'X-RateLimit-Used' => '1', 'X-RateLimit-Remaining' => '29' }, '{}'] }
        stubs.get('/used-only') { [200, { 'X-RateLimit-Used' => '7' }, '{}'] }
        stubs.get('/cached') do |env|
          env[:http_cache_trace] = [:fresh]
          [200, { 'X-RateLimit-Used' => '0', 'X-RateLimit-Remaining' => '5000' }, '{}']
        end
      end
    end
  end
end
