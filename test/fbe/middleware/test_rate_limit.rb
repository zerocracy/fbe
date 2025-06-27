# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'webmock'
require_relative '../../test__helper'
require_relative '../../../lib/fbe'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/rate_limit'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class RateLimitTest < Fbe::Test
  def test_caches_rate_limit_response_on_first_call
    rate_limit_response = {
      'rate' => {
        'limit' => 5000,
        'remaining' => 4999,
        'reset' => 1_672_531_200
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: rate_limit_response.to_json, headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    response = conn.get('/rate_limit')
    assert_equal 200, response.status
    assert_equal 4999, response.body['rate']['remaining']
  end

  def test_returns_cached_response_on_subsequent_calls
    rate_limit_response = {
      'rate' => {
        'limit' => 5000,
        'remaining' => 4999,
        'reset' => 1_672_531_200
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: rate_limit_response.to_json, headers: { 'Content-Type' => 'application/json' })
      .times(1)
    conn = create_connection
    conn.get('/rate_limit')
    response = conn.get('/rate_limit')
    assert_equal 200, response.status
    assert_equal 4999, response.body['rate']['remaining']
    assert_requested :get, 'https://api.github.com/rate_limit', times: 1
  end

  def test_decrements_remaining_count_for_non_rate_limit_requests
    rate_limit_response = {
      'rate' => {
        'limit' => 5000,
        'remaining' => 4999,
        'reset' => 1_672_531_200
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: rate_limit_response.to_json, headers: { 'Content-Type' => 'application/json',
                                                                            'X-RateLimit-Remaining' => '4999' })
    stub_request(:get, 'https://api.github.com/user')
      .to_return(status: 200, body: '{"login": "test"}', headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    conn.get('/rate_limit')
    conn.get('/user')
    response = conn.get('/rate_limit')
    assert_equal 4998, response.body['rate']['remaining']
    assert_equal '4998', response.headers['x-ratelimit-remaining']
  end

  def test_refreshes_cache_after_hundred_requests
    rate_limit_response = {
      'rate' => {
        'limit' => 5000,
        'remaining' => 4999,
        'reset' => 1_672_531_200
      }
    }
    refreshed_response = {
      'rate' => {
        'limit' => 5000,
        'remaining' => 4950,
        'reset' => 1_672_531_200
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: rate_limit_response.to_json, headers: { 'Content-Type' => 'application/json' })
      .then
      .to_return(status: 200, body: refreshed_response.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/user')
      .to_return(status: 200, body: '{"login": "test"}', headers: { 'Content-Type' => 'application/json' })
      .times(100)
    conn = create_connection
    conn.get('/rate_limit')
    100.times { conn.get('/user') }
    response = conn.get('/rate_limit')
    assert_equal 4950, response.body['rate']['remaining']
    assert_requested :get, 'https://api.github.com/rate_limit', times: 2
  end

  def test_handles_response_without_rate_data
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    response = conn.get('/rate_limit')
    assert_equal 200, response.status
    assert_empty(response.body)
  end

  def test_ignores_non_hash_response_body
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: 'invalid json', headers: { 'Content-Type' => 'text/plain' })
    conn = create_connection
    response = conn.get('/rate_limit')
    assert_equal 200, response.status
    assert_equal 'invalid json', response.body
  end

  def test_handles_zero_remaining_count
    rate_limit_response = {
      'rate' => {
        'limit' => 5000,
        'remaining' => 1,
        'reset' => 1_672_531_200
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: rate_limit_response.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/user')
      .to_return(status: 200, body: '{"login": "test"}', headers: { 'Content-Type' => 'application/json' })
      .times(2)
    conn = create_connection
    conn.get('/rate_limit')
    conn.get('/user')
    conn.get('/user')
    response = conn.get('/rate_limit')
    assert_equal 0, response.body['rate']['remaining']
  end

  private

  def create_connection
    Faraday.new(url: 'https://api.github.com') do |f|
      f.use Fbe::Middleware::RateLimit
      f.response :json
      f.adapter :net_http
    end
  end
end
