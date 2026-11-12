# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'tmpdir'
require 'webmock/minitest'
require_relative '../../lib/fbe/octo'
require_relative '../test__helper'

# Test.
class TestOctoCachedPagination < Fbe::Test
  def test_follows_all_pages_after_the_quota_recovers_while_a_page_is_cached
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: '{"rate":{"remaining":5000}}',
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '5000' }
    ).then.to_return(
      body: '{"rate":{"remaining":4000}}',
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '4000' }
    )
    url = 'https://api.github.com/repos/foo/bar/issues'
    stub_request(:get, url).with(query: { 'per_page' => '100' }).to_return(
      body: '[{"number":1}]',
      headers: {
        'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '0',
        'Cache-Control' => 'private, max-age=60',
        'Link' => "<#{url}?page=2&per_page=100>; rel=\"next\""
      }
    )
    stub_request(:get, url).with(query: { 'page' => '2', 'per_page' => '100' }).to_return(
      body: '[{"number":2}]',
      headers: {
        'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '3999',
        'Link' => "<#{url}?page=3&per_page=100>; rel=\"next\""
      }
    )
    stub_request(:get, url).with(query: { 'page' => '3', 'per_page' => '100' }).to_return(
      body: '[{"number":3}]',
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '3998' }
    )
    Dir.mktmpdir do |dir|
      cache = File.join(dir, 'cache.db')
      assert_equal([1], client(cache).list_issues('foo/bar').map(&:number))
      assert_equal([1, 2, 3], client(cache).list_issues('foo/bar').map(&:number))
    end
    assert_requested(:get, 'https://api.github.com/rate_limit', times: 2)
    assert_requested(:get, url, query: { 'per_page' => '100' }, times: 1)
    assert_requested(:get, url, query: { 'page' => '2', 'per_page' => '100' }, times: 1)
    assert_requested(:get, url, query: { 'page' => '3', 'per_page' => '100' }, times: 1)
  end

  private

  def client(cache)
    Fbe.octo(
      loog: Loog::NULL, global: {},
      options: Judges::Options.new('github_token' => 'x' * 40, 'sqlite_cache' => cache)
    )
  end
end
