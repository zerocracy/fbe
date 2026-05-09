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
  # NOT thread-safe: assumes single-threaded use (judges run sequentially in judges-action).
  #
  # Initializes the rate limit middleware.
  #
  # @param [Object] app The next middleware in the stack
  def initialize(app)
    super
    @cached = nil
    @remaining = 0
    @searchleft = 0
    @counter = 0
  end

  # Processes the HTTP request and handles rate limit caching.
  #
  # @param [Faraday::Env] env The request environment
  # @return [Faraday::Response] The response from cache or the next middleware
  def call(env)
    if env.url.path == '/rate_limit'
      handle_rate_limit_request(env)
    else
      track_request(env.url.path)
      @app.call(env)
    end
  end

  private

  # Handles requests to the rate_limit endpoint.
  #
  # @param [Faraday::Env] env The request environment
  # @return [Faraday::Response] Cached or fresh response
  def handle_rate_limit_request(env)
    if @cached.nil? || @counter >= 100
      response = @app.call(env)
      @cached = response
      @remaining = extract_remaining_count(response)
      @searchleft = extract_search_remaining_count(response)
      @counter = 0
      response
    else
      Faraday::Response.new(response_env(env, @cached))
    end
  end

  # Tracks non-rate_limit requests and decrements counter.
  def track_request(path = nil)
    @counter += 1
    if path&.start_with?('/search/')
      @searchleft -= 1 if @searchleft.positive?
    elsif @remaining.positive?
      @remaining -= 1
    end
  end

  # Extracts the remaining count from the response body.
  #
  # @param [Faraday::Response] response The API response
  # @return [Integer] The remaining requests count
  def extract_remaining_count(response)
    body = response.body
    body = JSON.parse(body) if body.is_a?(String)
    return 0 unless body.is_a?(Hash)
    body.dig('rate', 'remaining') || 0
  end

  # Extracts the search-resource remaining count from the response body.
  #
  # @param [Faraday::Response] response The API response
  # @return [Integer] The remaining search-API requests count
  def extract_search_remaining_count(response)
    body = response.body
    body = JSON.parse(body) if body.is_a?(String)
    return 0 unless body.is_a?(Hash)
    body.dig('resources', 'search', 'remaining') || 0
  end

  # Builds a fresh body with the current remaining counts written in,
  # without mutating the cached response. Uses a JSON round-trip for
  # the deep copy so we only handle JSON-shaped data.
  #
  # @param [Object] original The cached response body (Hash or JSON String)
  # @return [Object] A new body of the same type with remaining counts updated
  def patched_body(original)
    stringed = original.is_a?(String)
    body =
      if stringed
        JSON.parse(original)
      elsif original.is_a?(Hash)
        JSON.parse(original.to_json)
      else
        return original
      end
    body['rate']['remaining'] = @remaining if body['rate']
    body.dig('resources', 'search')&.[]=('remaining', @searchleft)
    stringed ? body.to_json : body
  end

  # Builds a response environment that mirrors the cached response,
  # preserving Faraday::Env invariants by dup-ing the original env
  # and only overriding body and rate-limit headers.
  #
  # @param [Faraday::Env] env The original request environment
  # @param [Faraday::Response] response The cached response
  # @return [Faraday::Env] Response env ready to wrap in Faraday::Response
  def response_env(env, response)
    served = response.env.dup
    served.request_headers = env.request_headers
    served.body = patched_body(response.body)
    served.response_headers = response.headers.dup
    served.response_headers['x-ratelimit-remaining'] = @remaining.to_s
    served
  end
end
