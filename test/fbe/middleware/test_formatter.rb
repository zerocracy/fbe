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

require 'faraday'
require 'loog'
require 'minitest/autorun'
require_relative '../../../lib/fbe'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/formatter'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Zerocracy
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
      assert_match(%r{http://example.com}, str)
      assert_match(/Authorization:/, str)
      assert_match(%r{HTTP/1.1 401}, str)
      assert_match(/x-github-api-version-selected: "2022-11-28"/, str)
      assert_match(/hello, world!/, str)
      assert_match(/request body/, str)
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
