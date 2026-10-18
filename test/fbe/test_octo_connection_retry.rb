# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock/minitest'
require_relative '../../lib/fbe/octo'
require_relative '../test__helper'

# Test.
class TestOctoConnectionRetry < Fbe::Test
  def setup
    super
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: '{"rate":{"remaining":5000}}',
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '5000' }
    )
  end

  def test_recovers_from_a_connection_reset
    assert_recovers_after(Errno::ECONNRESET)
  end

  def test_recovers_from_an_unexpected_end_of_file
    assert_recovers_after(EOFError)
  end

  def test_recovers_from_a_temporary_ssl_error
    assert_recovers_after(OpenSSL::SSL::SSLError)
  end

  def test_still_recovers_from_a_read_timeout
    assert_recovers_after(Net::ReadTimeout)
  end

  def test_stops_after_four_retries_and_preserves_the_error
    [Errno::ECONNRESET, EOFError, OpenSSL::SSL::SSLError].each_with_index do |error, idx|
      url = "https://api.github.com/users/failing-#{idx}"
      stub_request(:get, url).to_raise(error)
      expected = error == OpenSSL::SSL::SSLError ? Faraday::SSLError : Faraday::ConnectionFailed
      assert_raises(expected) { client.user("failing-#{idx}") }
      assert_requested(:get, url, times: 5)
    end
  end

  def test_does_not_retry_a_comment_write_after_a_connection_error
    [Errno::ECONNRESET, EOFError, OpenSSL::SSL::SSLError].each_with_index do |error, idx|
      url = "https://api.github.com/repos/foo/bar/issues/#{idx}/comments"
      stub_request(:post, url).to_raise(error).then.to_return(
        body: '{"id":42}', headers: { 'Content-Type' => 'application/json' }
      )
      expected = error == OpenSSL::SSL::SSLError ? Faraday::SSLError : Faraday::ConnectionFailed
      assert_raises(expected) { client.add_comment('foo/bar', idx, 'hello') }
      assert_requested(:post, url, times: 1)
    end
  end

  private

  def client
    Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
  end

  def assert_recovers_after(error)
    url = 'https://api.github.com/users/recovered'
    stub_request(:get, url).to_raise(error).then.to_return(
      body: '{"login":"recovered"}', headers: { 'Content-Type' => 'application/json' }
    )
    assert_equal('recovered', client.user('recovered')[:login])
    assert_requested(:get, url, times: 2)
  end
end
