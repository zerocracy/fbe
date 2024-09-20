# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require 'faraday'
require 'loog'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/logging_formatter'

class LoggingFormatterTest < Minitest::Test
  def test_success_response_with_debug_log_level
    run_logging_formatter(status: 200, log_level: Logger::DEBUG) do |logger|
      assert_empty(logger.to_s)
    end
  end

  def test_success_response_with_error_log_level
    run_logging_formatter(status: 307, log_level: Logger::ERROR) do |logger|
      assert_empty(logger.to_s)
    end
  end

  def test_error_response_with_debug_log_level
    run_logging_formatter(status: 400, log_level: Logger::DEBUG) do |logger|
      str = logger.to_s
      refute_empty(str)
      assert_match(%r{http://example.com}, str)
      assert_match(/Authorization: [\*]{8}cret"/, str)
      assert_match(/Status 400/, str)
      assert_match(/x-github-api-version-selected: "2022-11-28"/, str)
      assert_match(/some response body/, str)
    end
  end

  def test_error_response_with_error_log_level
    run_logging_formatter(method: :post, status: 500, log_level: Logger::ERROR) do |logger|
      str = logger.to_s
      refute_empty(str)
      assert_match(%r{http://example.com}, str)
      assert_match(/Authorization: [\*]{8}cret"/, str)
      assert_match(/some request body/, str)
      assert_match(/Status 500/, str)
      assert_match(/x-github-api-version-selected: "2022-11-28"/, str)
      assert_match(/some response body/, str)
    end
  end

  private

  def run_logging_formatter(status:, log_level:, method: :get)
    logger = Loog::Buffer.new(level: log_level)
    options = {
      log_only_errors: true,
      headers: true,
      bodies: true,
      errors: false
    }
    formatter = Fbe::Middleware::LoggingFormatter.new(logger:, options:)
    env = Faraday::Env.from(
      {
        method:,
        request_body: method == :get ? nil : 'some request body',
        url: URI('http://example.com'),
        request_headers: {
          'Authorization' => 'Bearer github_pat_11AAsecret'
        }
      }
    )
    formatter.request(env)
    env[:response_headers] = {
      'x-github-api-version-selected' => '2022-11-28'
    }
    env[:status] = status
    env[:response_body] = 'some response body'
    formatter.response(env)
    yield logger
  end
end
