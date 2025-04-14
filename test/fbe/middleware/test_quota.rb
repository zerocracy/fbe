# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'logger'
require 'loog'
require 'judges'
require 'judges/options'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/quota'
require_relative '../../test__helper'

class QuotaTest < Fbe::Test
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
    pause = 0.1
    app = FakeApp.new
    middleware = Fbe::Middleware::Quota.new(app, loog:, pause:)
    start_time = Time.now
    105.times do
      env = Judges::Options.new(
        'method' => :get,
        'url' => 'http://example.com',
        'request_headers' => {},
        'response_headers' => {}
      )
      middleware.call(env)
    end
    assert_in_delta pause, Time.now - start_time, 0.4
  end

  def test_quota_middleware_logs_when_quota_low
    pause = 0.1
    log_output = StringIO.new
    loog = Logger.new(log_output)
    app = FakeApp.new
    middleware = Fbe::Middleware::Quota.new(app, loog:, pause:)
    105.times do
      env = Judges::Options.new(
        'method' => :get,
        'url' => 'http://example.com',
        'request_headers' => {},
        'response_headers' => {}
      )
      middleware.call(env)
    end
    assert_match(/Too much GitHub API quota/, log_output.string)
  end
end
