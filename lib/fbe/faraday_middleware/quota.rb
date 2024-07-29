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

module Fbe
  module FaradayMiddleware
    # Faraday Middleware that monitors GitHub API rate limits.
    class Quota < Faraday::Middleware
      def initialize(app, options = {})
        super(app)
        @request_limit = 100
        @request_count = 0
        @app = app
        @logger = options[:logger]
        @pause_duration = options[:pause]
      end

      def call(env)
        @request_count += 1

        response = @app.call(env)
        if out_of_limit?(env)
          @logger.info(
            "Too much GitHub API quota consumed, pausing for #{@pause_duration} seconds"
          )
          sleep(@pause_duration)
          @request_count = 0
        end
        response
      end

      private

      def out_of_limit?(env)
        remaining = env.response_headers['x-ratelimit-remaining'].to_i
        (@request_count % @request_limit).zero? && remaining < 5
      end
    end
  end
end
