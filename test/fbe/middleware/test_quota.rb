# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'logger'
require 'loog'
require 'loog/tee'
require 'judges'
require 'judges/options'
require 'veil'
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
      env.response_headers['x-ratelimit-remaining'] = (10 - @calls).to_s
      env
    end
  end

  def test_quota_middleware_pauses_when_quota_low
    loog = Loog::NULL
    pause = 0.01
    app = FakeApp.new
    middleware = Fbe::Middleware::Quota.new(app, loog:, pause:, threshold: 5)
    start_time = Time.now
    env = Judges::Options.new(
      'method' => :get,
      'url' => 'http://example.com',
      'request_headers' => {},
      'response_headers' => {}
    )
    11.times do
      middleware.call(env)
    end
    assert_in_delta pause, Time.now - start_time, 0.4
  end

  def test_quota_middleware_logs_when_quota_low
    pause = 0.01
    log_output = StringIO.new
    loog = Loog::Tee.new(Logger.new(log_output), Loog::NULL)
    app = FakeApp.new
    middleware = Fbe::Middleware::Quota.new(app, loog:, pause:, threshold: 5)
    env = Judges::Options.new(
      'method' => :get,
      'url' => 'http://example.com',
      'request_headers' => {},
      'response_headers' => {}
    )
    11.times do
      middleware.call(env)
    end
    assert_match(/pausing for/, log_output.string)
  end
end
