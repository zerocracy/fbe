# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require_relative '../../fbe'
require_relative '../../fbe/middleware'

# Faraday middleware that traces all API calls.
#
# This middleware records all HTTP requests and responses in a trace array,
# capturing method, URL, status, and timing information for debugging and
# monitoring purposes.
#
# @example Usage in Faraday middleware stack
#   trace = []
#   connection = Faraday.new do |f|
#     f.use Fbe::Middleware::Trace, trace
#   end
#   connection.get('/api/endpoint')
#   trace.first[:method] #=> :get
#   trace.first[:url] #=> 'https://example.com/api/endpoint'
#   trace.first[:status] #=> 200
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Middleware::Trace < Faraday::Middleware
  # Initializes the trace middleware.
  #
  # @param [Object] app The next middleware in the stack
  # @param [Array] trace The array to store trace entries
  def initialize(app, trace)
    super(app)
    @trace = trace
  end

  # Processes the HTTP request and records trace information.
  #
  # @param [Faraday::Env] env The request environment
  # @return [Faraday::Response] The response from the next middleware
  def call(env)
    started = Time.now
    trace_entry = {
      method: env.method,
      url: env.url.to_s,
      started_at: started
    }
    @app.call(env).on_complete do |response_env|
      finished = Time.now
      trace_entry[:status] = response_env.status
      trace_entry[:finished_at] = finished
      trace_entry[:duration] = finished - started
      @trace << trace_entry
    end
  end
end
