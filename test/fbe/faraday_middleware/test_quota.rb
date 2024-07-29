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
require 'logger'
require_relative '../../../lib/fbe/faraday_middleware'

class QuotaTest < Minitest::Test
  class FakeApp
    def initialize
      @calls = 0
    end

    def call(env)
      @calls += 1
      response_headers = {
        'x-ratelimit-remaining' => (100 - @calls).to_s
      }
      env[:response_headers] = response_headers
      env
    end
  end

  def test_quota_middleware_pauses_when_quota_low
    loog = Loog::NULL
    pause = 0
    app = FakeApp.new
    middleware = Fbe::FaradayMiddleware::Quota.new(app, logger: loog, github_api_pause: pause)
    start_time = Time.now
    105.times do
      env = Judges::Options.new(
        {
          'method' => :get,
          'url' => 'http://example.com',
          'request_headers' => {},
          'response_headers' => {}
        }
      )
      middleware.call(env)
    end
    assert_in_delta pause, Time.now - start_time, 0.4
  end

  def test_quota_middleware_logs_when_quota_low
    pause = 1
    log_output = StringIO.new
    loog = Logger.new(log_output)
    app = FakeApp.new
    middleware = Fbe::FaradayMiddleware::Quota.new(app, logger: loog, github_api_pause: pause)
    105.times do
      env = Judges::Options.new(
        {
          'method' => :get,
          'url' => 'http://example.com',
          'request_headers' => {},
          'response_headers' => {}
        }
      )
      middleware.call(env)
    end
    assert_match(/Too much GitHub API quota/, log_output.string)
  end
end
