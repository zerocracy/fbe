# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require_relative '../../../lib/fbe'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/rate_limit'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class RateLimitLockTest < Fbe::Test
  def test_frees_the_lock_while_the_rate_limit_request_is_in_flight
    middleware = nil
    held = nil
    app =
      lambda do |env|
        held = middleware.instance_variable_get(:@lock).locked?
        env.status = 200
        env.body = { 'rate' => { 'limit' => 5000, 'remaining' => 4999 } }
        env.response_headers = { 'x-ratelimit-remaining' => '4999' }
        Faraday::Response.new(env)
      end
    middleware = Fbe::Middleware::RateLimit.new(app)
    env = Faraday::Env.from(url: URI('https://api.github.com/rate_limit'), request_headers: {})
    middleware.call(env)
    refute(held, 'the lock was held while the rate_limit request was in flight')
  end
end
