# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'loog'
require 'securerandom'
require_relative '../../../lib/fbe'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/formatter'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class LoggingFormatterTest < Fbe::Test
  def test_filters_response_messages_for_both_error_formats
    [401, 403].each do |status|
      loog = Loog::Buffer.new
      formatter = Fbe::Middleware::Formatter.new(logger: loog, options: {})
      formatter.filter(/private detail/, '[REDACTED]')
      env = Faraday::Env.from({ method: :get, url: URI('http://example.com'), request_headers: {} })
      env.status = status
      env.response_headers = { 'content-type' => 'application/json' }
      env.response_body = '{"message":"Access denied: private detail"}'
      formatter.response(env)
      assert_includes(loog.to_s, '[REDACTED]')
      refute_includes(loog.to_s, 'private detail')
    end
  end

  def test_success_response
    log_it(status: 200) do |loog|
      assert_empty(loog.to_s)
    end
  end

  def test_forward_response
    log_it(status: 303) do |loog|
      assert_empty(loog.to_s)
    end
  end

  def test_error_response
    log_it(status: 401) do |loog|
      str = loog.to_s
      refute_empty(str)
      [
        %r{http://example.com},
        /Authorization: "Bearer \[FILTERED\]"/,
        %r{HTTP/1.1 401},
        /x-github-api-version-selected: "2022-11-28"/,
        /hello, world!/,
        /request body/
      ].each { |ptn| assert_match(ptn, str) }
      refute_match(/github_pat_11AAsecret/, str, 'live token must never appear in the log')
    end
  end

  def test_limit_response
    log_it(status: 403) do |loog|
      str = loog.to_s
      refute_empty(str)
    end
  end

  def test_limit_response_without_content_type_header
    log_it(status: 403, response_body: '', response_headers: {}) do |loog|
      str = loog.to_s
      refute_empty(str)
      assert_match(%r{http://example.com}, str)
      assert_match(%r{HTTP/1.1 403}, str)
    end
  end

  def test_limit_response_with_empty_json_body
    log_it(status: 403, response_body: '') do |loog|
      str = loog.to_s
      refute_empty(str)
      assert_match(%r{http://example.com}, str)
      assert_match(%r{HTTP/1.1 403}, str)
    end
  end

  def test_limit_response_with_json_body_without_message
    log_it(status: 403, response_body: '{}') do |loog|
      str = loog.to_s
      refute_empty(str)
      assert_match(%r{HTTP/1.1 403}, str)
      assert_match(/\{\}/, str)
    end
  end

  def test_limit_response_with_malformed_json_body
    log_it(status: 403, response_body: '<html>denied</html>') do |loog|
      str = loog.to_s
      refute_empty(str)
      assert_match(%r{HTTP/1.1 403}, str)
      assert_match(%r{<html>denied</html>}, str)
    end
  end

  def test_filters_basic_auth_credentials_from_log
    log_it(status: 500, request_headers: { 'Authorization' => 'Basic dXNlcjpwYXNzd29yZA==' }) do |loog|
      str = loog.to_s
      assert_match(/Authorization: "Basic \[FILTERED\]"/, str)
      refute_match(/dXNlcjpwYXNzd29yZA==/, str, 'Basic credentials must never appear in the log')
    end
  end

  def test_filters_lowercase_token_scheme_from_log
    log_it(status: 500, request_headers: { 'Authorization' => 'token ghs_secrettoken123' }) do |loog|
      str = loog.to_s
      assert_match(/Authorization: "token \[FILTERED\]"/, str)
      refute_match(/ghs_secrettoken123/, str, 'token-scheme credential must never appear in the log')
    end
  end

  def test_filters_credential_without_scheme_within_its_line
    log_it(status: 500, request_headers: { 'Authorization' => 'ghs_secret42', 'Accept' => 'text/plain' }) do |loog|
      str = loog.to_s
      assert_match(/Authorization: "\[FILTERED\]"/, str)
      assert_match(%r{Accept: "text/plain"}, str)
      refute_match(/ghs_secret42/, str, 'credential without a scheme must never appear in the log')
    end
  end

  def test_truncate_body_for_error_text_response
    body = SecureRandom.alphanumeric(120)
    log_it(
      status: 502,
      response_body: body,
      response_headers: {
        'content-type' => 'text/html; charset=utf-8',
        'x-github-api-version-selected' => '2022-11-28'
      }
    ) do |loog|
      str = loog.to_s
      refute_empty(str)
      [
        %r{http://example.com},
        /Authorization: "Bearer \[FILTERED\]"/,
        /some request body/,
        %r{HTTP/1.1 502},
        /x-github-api-version-selected: "2022-11-28"/,
        %r{content-type: "text/html; charset=utf-8"},
        "#{body.slice(0, 97)}..."
      ].each { |ptn| assert_match(ptn, str) }
      refute_match(/github_pat_11AAsecret/, str, 'live token must never appear in the log')
    end
  end

  def test_logs_the_request_the_response_belongs_to
    loog = Loog::Buffer.new
    formatter = Fbe::Middleware::Formatter.new(logger: loog, options: {})
    %w[alpha bravo].each do |name|
      env = Faraday::Env.from({ method: :get, url: URI("http://example.com/#{name}"), request_headers: {} })
      formatter.request(env)
      next unless name == 'alpha'
      env.status = 403
      env.response_headers = { 'content-type' => 'application/json' }
      env.response_body = '{"message": "rate limit"}'
      formatter.response(env)
    end
    str = loog.to_s
    assert_match(%r{http://example.com/alpha}, str)
    refute_match(%r{http://example.com/bravo}, str, 'the response is logged against the wrong request')
  end

  def test_uses_warning_for_json_regardless_of_media_type_case
    ['application/json', 'Application/JSON; Charset=UTF-8', 'APPLICATION/JSON'].each do |type|
      logger = Loog::Buffer.new
      warnings = []
      formatter = Fbe::Middleware::Formatter.new(logger:, options: {})
      env = Faraday::Env.from(
        {
          method: :get, url: URI('http://example.com'), status: 403,
          request_headers: {}, response_headers: { 'content-type' => type },
          response_body: '{"message":"denied"}'
        }
      )
      logger.stub(:warn, ->(message) { warnings << message }) do
        formatter.response(env)
      end
      assert_equal(['GET http://example.com -> 403 / denied'], warnings)
    end
  end

  def test_truncates_text_regardless_of_media_type_case
    body = 'x' * 120
    ['text/plain', 'Text/Plain; Charset=UTF-8', 'TEXT/HTML'].each do |type|
      log_it(status: 502, response_body: body, response_headers: { 'content-type' => type }) do |loog|
        assert_includes(loog.to_s, "#{body[0, 97]}...")
        refute_includes(loog.to_s, body)
        assert_includes(loog.to_s, "content-type: #{type.inspect}")
      end
    end
  end

  def test_transcodes_valid_bodies_before_filtering_and_truncation
    body = "Ошибка #{'x' * 110}"
    %w[UTF-16LE UTF-16BE UTF-32LE UTF-32BE].product([404, 502]).each do |encoding, status|
      log_it(
        status:,
        request_body: 'Authorization: Bearer body-secret'.encode(encoding),
        response_body: body.encode(encoding),
        response_headers: { 'content-type' => "text/plain; charset=#{encoding.downcase}" }
      ) do |loog, env|
        expected = status == 502 ? "#{body[0, 97]}..." : body
        [expected, 'Authorization: Bearer [FILTERED]'].each { |text| assert_includes(loog.to_s, text) }
        refute_includes(loog.to_s, 'body-secret')
        assert_equal(
          [Encoding::UTF_8, Encoding.find(encoding), Encoding.find(encoding)],
          [loog.to_s.encoding, env.response_body.encoding, env.request_body.encoding]
        )
      end
    end
  end

  def test_logs_binary_response_bodies
    body = "\xFFdata".b
    log_it(status: 404, response_body: body) do |loog|
      assert_includes(loog.to_s, 'data')
    end
  end

  def test_survives_a_response_without_a_request
    loog = Loog::Buffer.new
    formatter = Fbe::Middleware::Formatter.new(logger: loog, options: {})
    env = Faraday::Env.from({ method: :get, url: URI('http://example.com'), request_headers: {} })
    env.status = 500
    env.response_headers = { 'content-type' => 'text/html' }
    env.response_body = 'oops'
    formatter.response(env)
    assert_match(/oops/, loog.to_s)
  end

  private

  def log_it(
    status:,
    method: :get,
    request_body: 'some request body',
    response_body: '{"message": "hello, world!"}',
    response_headers: { 'content-type' => 'application/json', 'x-github-api-version-selected' => '2022-11-28' },
    request_headers: { 'Authorization' => 'Bearer github_pat_11AAsecret' }
  )
    loog = Loog::Buffer.new
    formatter = Fbe::Middleware::Formatter.new(logger: loog, options: {})
    env = Faraday::Env.from({ method:, request_body:, url: URI('http://example.com'), request_headers: })
    formatter.request(env)
    env.status = status
    env.response_headers = response_headers
    env.response_body = response_body
    formatter.response(env)
    yield(loog, env)
  end
end
