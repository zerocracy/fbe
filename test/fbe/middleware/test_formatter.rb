# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'loog'
require 'minitest/autorun'
require_relative '../../../lib/fbe'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/formatter'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class LoggingFormatterTest < Minitest::Test
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
        /Authorization:/,
        %r{HTTP/1.1 401},
        /x-github-api-version-selected: "2022-11-28"/,
        /hello, world!/,
        /request body/
      ].each { |ptn| assert_match(ptn, str) }
    end
  end

  def test_limit_response
    log_it(status: 403) do |loog|
      str = loog.to_s
      refute_empty(str)
    end
  end

  private

  def log_it(status:, method: :get)
    loog = Loog::Buffer.new
    formatter = Fbe::Middleware::Formatter.new(logger: loog, options: {})
    formatter.request(
      Faraday::Env.from(
        {
          method:,
          request_body: 'some request body',
          url: URI('http://example.com'),
          request_headers: {
            'Authorization' => 'Bearer github_pat_11AAsecret'
          }
        }
      )
    )
    formatter.response(
      Faraday::Env.from(
        {
          status:,
          response_body: '{"message": "hello, world!"}',
          response_headers: {
            'content-type' => 'application/json',
            'x-github-api-version-selected' => '2022-11-28'
          }
        }
      )
    )
    yield loog
  end
end
