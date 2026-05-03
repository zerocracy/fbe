# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'webmock'
require_relative '../../../lib/fbe'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/rate_limit'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class RateLimitTest < Fbe::Test
  def test_caches_payload_on_first_call
    payload = { 'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 } }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    response = conn.get('/rate_limit')
    assert_equal(200, response.status)
    assert_equal(4999, response.body['rate']['remaining'])
  end

  def test_returns_cached_response_on_subsequent_calls
    payload = { 'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 } }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
      .times(1)
    conn = create_connection
    conn.get('/rate_limit')
    response = conn.get('/rate_limit')
    assert_equal(200, response.status)
    assert_equal(4999, response.body['rate']['remaining'])
    assert_requested(:get, 'https://api.github.com/rate_limit', times: 1)
  end

  def test_decrements_remaining_count_for_non_rate_limit_requests
    payload = { 'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 } }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json',
                                                                'X-RateLimit-Remaining' => '4999' })
    stub_request(:get, 'https://api.github.com/user')
      .to_return(status: 200, body: '{"login": "test"}', headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    conn.get('/rate_limit')
    conn.get('/user')
    response = conn.get('/rate_limit')
    assert_equal(4998, response.body['rate']['remaining'])
    assert_equal('4998', response.headers['x-ratelimit-remaining'])
  end

  def test_refreshes_cache_after_hundred_requests
    payload = { 'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 } }
    refreshed = { 'rate' => { 'limit' => 5000, 'remaining' => 4950, 'reset' => 1_672_531_200 } }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
      .then
      .to_return(status: 200, body: refreshed.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/user')
      .to_return(status: 200, body: '{"login": "test"}', headers: { 'Content-Type' => 'application/json' })
      .times(100)
    conn = create_connection
    conn.get('/rate_limit')
    100.times { conn.get('/user') }
    response = conn.get('/rate_limit')
    assert_equal(4950, response.body['rate']['remaining'])
    assert_requested(:get, 'https://api.github.com/rate_limit', times: 2)
  end

  def test_handles_response_without_rate_data
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    response = conn.get('/rate_limit')
    assert_equal(200, response.status)
    assert_empty(response.body)
  end

  def test_handles_zero_remaining_count
    payload = { 'rate' => { 'limit' => 5000, 'remaining' => 1, 'reset' => 1_672_531_200 } }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/user')
      .to_return(status: 200, body: '{"login": "test"}', headers: { 'Content-Type' => 'application/json' })
      .times(2)
    conn = create_connection
    conn.get('/rate_limit')
    conn.get('/user')
    conn.get('/user')
    response = conn.get('/rate_limit')
    assert_equal(0, response.body['rate']['remaining'])
  end

  def test_decrements_search_remaining_for_search_requests
    payload = {
      'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
      'resources' => {
        'core' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
        'search' => { 'limit' => 30, 'remaining' => 30, 'reset' => 1_672_531_200 }
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/search/issues?q=foo')
      .to_return(status: 200, body: '{"items":[]}', headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    conn.get('/rate_limit')
    conn.get('/search/issues?q=foo')
    response = conn.get('/rate_limit')
    assert_equal(29, response.body['resources']['search']['remaining'])
    assert_equal(4999, response.body['rate']['remaining'])
  end

  def test_search_request_does_not_decrement_core_remaining
    payload = {
      'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
      'resources' => {
        'core' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
        'search' => { 'limit' => 30, 'remaining' => 30, 'reset' => 1_672_531_200 }
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/search/code?q=bar')
      .to_return(status: 200, body: '{"items":[]}', headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    conn.get('/rate_limit')
    conn.get('/search/code?q=bar')
    response = conn.get('/rate_limit')
    assert_equal(4999, response.body['rate']['remaining'])
  end

  def test_non_search_request_does_not_decrement_search_remaining
    payload = {
      'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
      'resources' => {
        'core' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
        'search' => { 'limit' => 30, 'remaining' => 30, 'reset' => 1_672_531_200 }
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/user')
      .to_return(status: 200, body: '{"login":"x"}', headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    conn.get('/rate_limit')
    conn.get('/user')
    response = conn.get('/rate_limit')
    assert_equal(30, response.body['resources']['search']['remaining'])
    assert_equal(4998, response.body['rate']['remaining'])
  end

  def test_search_remaining_survives_repeated_search_calls_within_cache_window
    payload = {
      'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
      'resources' => {
        'core' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
        'search' => { 'limit' => 30, 'remaining' => 30, 'reset' => 1_672_531_200 }
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
      .times(1)
    stub_request(:get, 'https://api.github.com/search/issues?q=z')
      .to_return(status: 200, body: '{"items":[]}', headers: { 'Content-Type' => 'application/json' })
      .times(25)
    conn = create_connection
    conn.get('/rate_limit')
    25.times { conn.get('/search/issues?q=z') }
    response = conn.get('/rate_limit')
    assert_equal(5, response.body['resources']['search']['remaining'])
    assert_requested(:get, 'https://api.github.com/rate_limit', times: 1)
  end

  def test_search_remaining_clamps_at_zero
    payload = {
      'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
      'resources' => {
        'core' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
        'search' => { 'limit' => 30, 'remaining' => 1, 'reset' => 1_672_531_200 }
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/search/issues?q=z')
      .to_return(status: 200, body: '{"items":[]}', headers: { 'Content-Type' => 'application/json' })
      .times(3)
    conn = create_connection
    conn.get('/rate_limit')
    3.times { conn.get('/search/issues?q=z') }
    response = conn.get('/rate_limit')
    assert_equal(0, response.body['resources']['search']['remaining'])
  end

  def test_search_remaining_absent_when_payload_lacks_resources
    payload = { 'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 } }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/search/issues?q=z')
      .to_return(status: 200, body: '{"items":[]}', headers: { 'Content-Type' => 'application/json' })
    conn = create_connection
    conn.get('/rate_limit')
    conn.get('/search/issues?q=z')
    response = conn.get('/rate_limit')
    refute(response.body.key?('resources'), 'must not invent a resources key when upstream did not return one')
    assert_equal(4999, response.body['rate']['remaining'])
  end

  def test_decrement_applies_when_body_is_a_json_string
    payload = {
      'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
      'resources' => {
        'core' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
        'search' => { 'limit' => 30, 'remaining' => 30, 'reset' => 1_672_531_200 }
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.github.com/search/issues?q=z')
      .to_return(status: 200, body: '{"items":[]}', headers: { 'Content-Type' => 'application/json' })
    conn =
      Faraday.new(url: 'https://api.github.com') do |f|
        f.use(Fbe::Middleware::RateLimit)
        f.adapter(:net_http)
      end
    conn.get('/rate_limit')
    conn.get('/search/issues?q=z')
    response = conn.get('/rate_limit')
    assert_kind_of(String, response.body, 'body must remain a String when no JSON parser middleware is installed')
    parsed = JSON.parse(response.body)
    assert_equal(29, parsed['resources']['search']['remaining'])
    assert_equal(4999, parsed['rate']['remaining'])
  end

  def test_cached_body_is_not_leaked_to_callers
    payload = {
      'rate' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
      'resources' => {
        'core' => { 'limit' => 5000, 'remaining' => 4999, 'reset' => 1_672_531_200 },
        'search' => { 'limit' => 30, 'remaining' => 30, 'reset' => 1_672_531_200 }
      }
    }
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
      .times(1)
    stub_request(:get, 'https://api.github.com/user')
      .to_return(status: 200, body: '{"login":"x"}', headers: { 'Content-Type' => 'application/json' })
      .times(2)
    conn = create_connection
    conn.get('/rate_limit')
    first = conn.get('/rate_limit')
    first.body['rate']['remaining'] = 0
    first.body['resources']['search']['remaining'] = 0
    conn.get('/user')
    conn.get('/user')
    second = conn.get('/rate_limit')
    refute_equal(
      0, second.body['rate']['remaining'],
      'mutating the body of an earlier cached response must not corrupt subsequent reads'
    )
    assert_equal(4997, second.body['rate']['remaining'])
    assert_equal(30, second.body['resources']['search']['remaining'])
  end

  private

  def create_connection
    Faraday.new(url: 'https://api.github.com') do |f|
      f.use(Fbe::Middleware::RateLimit)
      f.response(:json)
      f.adapter(:net_http)
    end
  end
end
