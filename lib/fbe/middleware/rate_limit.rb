# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'json'
require_relative '../../fbe'
require_relative '../../fbe/middleware'

# Faraday middleware that caches GitHub API rate limit information.
#
# This middleware intercepts calls to the /rate_limit endpoint and caches
# the results locally. It tracks the remaining requests count and decrements
# it for each API call. Every 100 requests, it refreshes the cached data
# by allowing the request to pass through to the GitHub API.
#
# @example Usage in Faraday middleware stack
#   connection = Faraday.new do |f|
#     f.use Fbe::Middleware::RateLimit
#   end
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class Fbe::Middleware::RateLimit < Faraday::Middleware
  # Initializes the rate limit middleware.
  #
  # @param [Object] app The next middleware in the stack
  def initialize(app)
    super
    @cached_response = nil
    @remaining_count = nil
    @request_counter = 0
  end

  # Processes the HTTP request and handles rate limit caching.
  #
  # @param [Faraday::Env] env The request environment
  # @return [Faraday::Response] The response from cache or the next middleware
  def call(env)
    if env.url.path == '/rate_limit'
      handle_rate_limit_request(env)
    else
      track_request
      @app.call(env)
    end
  end

  private

  # Handles requests to the rate_limit endpoint.
  #
  # @param [Faraday::Env] env The request environment
  # @return [Faraday::Response] Cached or fresh response
  def handle_rate_limit_request(env)
    if @cached_response.nil? || @request_counter >= 100
      response = @app.call(env)
      @cached_response = response.dup
      @remaining_count = extract_remaining_count(response)
      @request_counter = 0
      response
    else
      response = @cached_response.dup
      update_remaining_count(response)
      Faraday::Response.new(response_env(env, response))
    end
  end

  # Tracks non-rate_limit requests and decrements counter.
  def track_request
    return if @remaining_count.nil?
    @remaining_count -= 1 if @remaining_count.positive?
    @request_counter += 1
  end

  # Extracts the remaining count from the response body.
  #
  # @param [Faraday::Response] response The API response
  # @return [Integer] The remaining requests count
  def extract_remaining_count(response)
    body = response.body
    if body.is_a?(String)
      begin
        body = JSON.parse(body)
      rescue JSON::ParserError
        return 0
      end
    end
    return 0 unless body.is_a?(Hash)
    body.dig('rate', 'remaining') || 0
  end

  # Updates the remaining count in the response body.
  #
  # @param [Faraday::Response] response The cached response to update
  def update_remaining_count(response)
    body = response.body
    original_was_string = body.is_a?(String)
    if original_was_string
      begin
        body = JSON.parse(body)
      rescue JSON::ParserError
        return
      end
    end
    return unless body.is_a?(Hash) && body['rate']
    body['rate']['remaining'] = @remaining_count
    return unless original_was_string
    response.instance_variable_set(:@body, body.to_json)
  end

  # Creates a response environment for the cached response.
  #
  # @param [Faraday::Env] env The original request environment
  # @param [Faraday::Response] response The cached response
  # @return [Hash] Response environment hash
  def response_env(env, response)
    headers = response.headers.dup
    headers['x-ratelimit-remaining'] = @remaining_count.to_s if @remaining_count
    {
      method: env.method,
      url: env.url,
      request_headers: env.request_headers,
      request_body: env.request_body,
      status: response.status,
      response_headers: headers,
      body: response.body
    }
  end
end
