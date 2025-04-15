# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require_relative '../middleware'

# Faraday Middleware that monitors GitHub API rate limits.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Middleware::Quota < Faraday::Middleware
  # Constructor.
  #
  # @param [Object] app The Faraday app
  # @param [Loog] loog The logging facility
  # @param [Integer] pause Seconds to pause when rate limit is reached
  # @param [Integer] threshold Minimum remaining requests threshold (pause if less)
  def initialize(app, loog: Loog::NULL, pause: 60, threshold: 50)
    super(app)
    @app = app
    raise 'The "loog" cannot be nil' if loog.nil?
    @loog = loog
    raise 'The "pause" cannot be nil' if pause.nil?
    raise 'The "pause" must be a positive number' unless pause.positive?
    @pause = pause
    raise 'The "rate" cannot be nil' if threshold.nil?
    raise 'The "rate" must be a positive integer' unless threshold.positive?
    @threshold = threshold
  end

  # Process the request and handle rate limiting.
  #
  # @param [Faraday::Env] env The environment
  # @return [Faraday::Response] The response
  def call(env)
    ret = @app.call(env)
    remaining = env.response_headers['x-ratelimit-remaining']&.to_i
    if remaining && remaining < @threshold
      @loog.info("Only #{remaining} GitHub API quota remained, pausing for #{@pause} seconds")
      sleep(@pause)
    end
    ret
  end
end
