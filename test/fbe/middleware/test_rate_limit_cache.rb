# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'faraday/http_cache'
require 'webmock'
require_relative '../../../lib/fbe'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/rate_limit'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class RateLimitCacheTest < Fbe::Test
  def test_spends_no_quota_on_a_cached_response
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      status: 200,
      body: { 'rate' => { 'remaining' => 4_999 } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '4999' }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(
      status: 200,
      body: '{"id":42}',
      headers: {
        'Content-Type' => 'application/json',
        'Cache-Control' => 'max-age=600',
        'X-RateLimit-Remaining' => '4998'
      }
    )
    tracker = {}
    conn =
      Faraday.new(url: 'https://api.github.com') do |f|
        f.use(Fbe::Middleware::RateLimit, tracker)
        f.use(Faraday::HttpCache, serializer: Marshal, shared_cache: false, logger: Loog::NULL)
        f.adapter(:net_http)
      end
    conn.get('/rate_limit')
    10.times { conn.get('/repos/foo/bar') }
    assert_equal(4_998, tracker[:rate_limit].remaining)
  end
end
