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

# Faraday Middleware that monitors GitHub API rate limits.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Zerocracy
# License:: MIT
class Fbe::Middleware::Quota < Faraday::Middleware
  def initialize(app, loog: Loog::NULL, pause: 60, limit: 100, rate: 5)
    super(app)
    @requests = 0
    @app = app
    raise 'The "loog" cannot be nil' if loog.nil?
    @loog = loog
    raise 'The "pause" cannot be nil' if pause.nil?
    raise 'The "pause" must be a positive integer' unless pause.positive?
    @pause = pause
    raise 'The "limit" cannot be nil' if limit.nil?
    raise 'The "limit" must be a positive integer' unless limit.positive?
    @limit = limit
    raise 'The "rate" cannot be nil' if rate.nil?
    raise 'The "rate" must be a positive integer' unless rate.positive?
    @rate = rate
  end

  def call(env)
    @requests += 1
    response = @app.call(env)
    if out_of_limit?(env)
      @loog.info(
        "Too much GitHub API quota consumed, pausing for #{@pause} seconds"
      )
      sleep(@pause)
      @requests = 0
    end
    response
  end

  private

  def out_of_limit?(env)
    remaining = env.response_headers['x-ratelimit-remaining'].to_i
    (@requests % @limit).zero? && remaining < @rate
  end
end
