# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require_relative '../../lib/fbe/octo'
require_relative '../test__helper'

class TestOctoDiagnostics < Fbe::Test
  def test_rejects_a_repository_response_without_an_id
    client = octo
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(
      body: '{}', headers: { 'Content-Type' => 'application/json' }
    )
    error = assert_raises(Fbe::Error) { client.repo_id_by_name('foo/bar') }
    assert_includes(error.message, 'Repository foo/bar not found')
  end

  def test_wraps_forbidden_access_when_resolving_a_repository_name
    client = octo
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(status: 403, body: '{}')
    error = assert_raises(Fbe::Error) { client.repo_name_by_id(42) }
    assert_includes(error.message, 'GitHub repository #42 is not accessible')
    assert_instance_of(Octokit::Forbidden, error.cause)
  end

  def test_allows_the_cached_quota_method_when_off_quota
    client = octo(remaining: 10)
    assert_predicate(client, :off_quota?)
    assert_equal(10, client.rate_limit.remaining)
  end

  def test_includes_the_remaining_quota_in_the_error
    client = octo(remaining: 10)
    error = assert_raises(Fbe::OffQuota) { client.user(42) }
    assert_includes(error.message, 'remaining: 10')
    assert_not_requested(:get, 'https://api.github.com/user/42')
  end

  def test_does_not_emit_a_search_fallback_warning_for_the_core_quota
    loog = Loog::Buffer.new
    client = Fbe.octo(options: Judges::Options.new({ 'testing' => true }), global: {}, loog:)
    refute_predicate(client, :off_quota?)
    refute_includes(loog.to_s, 'Search-quota check fell back')
  end

  def test_omits_fast_requests_from_the_default_trace
    loog = Loog::Buffer.new
    now = Time.utc(2026, 1, 1)
    Time.stub(:now, -> { now }) do
      client = octo(loog:)
      { 42 => 0.01, 43 => 1 }.each do |id, delay|
        stub_request(:get, "https://api.github.com/user/#{id}").to_return do
          now += delay
          { body: '{}', headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '500' } }
        end
      end
      client.user(42)
      client.user(43)
      client.print_trace!
    end
    assert_includes(loog.to_s, '/user/43: 1')
    refute_includes(loog.to_s, '/user/42: 1')
  end

  private

  def octo(remaining: 500, loog: Loog::NULL)
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => remaining.to_s }
    )
    Fbe.octo(options: Judges::Options.new({ 'github_token' => 'synthetic-token' }), global: {}, loog:)
  end
end
