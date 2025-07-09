# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'ellipsized'
require 'faraday'
require 'faraday/logging/formatter'
require_relative '../../fbe'
require_relative '../../fbe/middleware'

# Custom Faraday formatter that logs only error responses (4xx/5xx).
#
# This formatter reduces log noise by only outputting details when HTTP
# requests fail. For 403 errors with JSON responses, it shows a compact
# warning with the error message. For other errors, it logs the full
# request/response details including headers and bodies.
#
# @example Usage in Faraday middleware
#   connection = Faraday.new do |f|
#     f.response :logger, nil, formatter: Fbe::Middleware::Formatter
#   end
#
# @example Log output for 403 error
#   # GET https://api.github.com/repos/private/repo -> 403 / Repository access denied
#
# @example Log output for other errors (500, 404, etc)
#   # GET https://api.example.com/endpoint HTTP/1.1
#   #   Content-Type: "application/json"
#   #   Authorization: "Bearer [FILTERED]"
#   #
#   #   {"query": "data"}
#   # HTTP/1.1 500
#   #   Content-Type: "text/html"
#   #
#   #   Internal Server Error
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Middleware::Formatter < Faraday::Logging::Formatter
  # Captures HTTP request details for later use in error logging.
  #
  # @param [Hash] http Request data including method, url, headers, and body
  # @return [void]
  def request(http)
    @req = http
  end

  # Logs HTTP response details only for error responses (4xx/5xx).
  #
  # @param [Hash] http Response data including status, headers, and body
  # @return [void]
  # @note Only logs when status >= 400
  # @note Special handling for 403 JSON responses to show compact error message
  def response(http)
    return if http.status < 400
    if http.status == 403 && http.response_headers['content-type'].start_with?('application/json')
      warn(
        [
          "#{@req.method.upcase} #{apply_filters(@req.url.to_s)}",
          '->',
          http.status,
          '/',
          JSON.parse(http.response_body)['message']
        ].join(' ')
      )
      return
    end
    if http.status >= 500 && http.response_headers['content-type']&.start_with?('text')
      error(
        [
          "#{@req.method.upcase} #{apply_filters(@req.url.to_s)} HTTP/1.1",
          shifted(apply_filters(dump_headers(@req.request_headers))),
          '',
          shifted(apply_filters(@req.request_body)),
          "HTTP/1.1 #{http.status}",
          shifted(apply_filters(dump_headers(http.response_headers))),
          '',
          shifted(apply_filters(http.response_body&.ellipsized(100, :right)))
        ].join("\n")
      )
      return
    end
    error(
      [
        "#{@req.method.upcase} #{apply_filters(@req.url.to_s)} HTTP/1.1",
        shifted(apply_filters(dump_headers(@req.request_headers))),
        '',
        shifted(apply_filters(@req.request_body)),
        "HTTP/1.1 #{http.status}",
        shifted(apply_filters(dump_headers(http.response_headers))),
        '',
        shifted(apply_filters(http.response_body))
      ].join("\n")
    )
  end

  private

  # Indents text with two spaces, including all lines.
  #
  # @param [String, nil] txt The text to indent
  # @return [String] The indented text, or an empty string if input was nil
  # @example
  #   shifted("line1\nline2")
  #   #=> "  line1\n  line2"
  def shifted(txt)
    return '' if txt.nil?
    "  #{txt.gsub("\n", "\n  ")}"
  end

  # Formats HTTP headers as a multi-line string.
  #
  # @param [Hash, nil] headers The headers to format
  # @return [String] The formatted headers, or an empty string if input was nil
  # @example
  #   dump_headers({"Content-Type" => "application/json", "Authorization" => "Bearer token"})
  #   #=> "Content-Type: \"application/json\"\nAuthorization: \"Bearer token\""
  def dump_headers(headers)
    return '' if headers.nil?
    headers.map { |k, v| "#{k}: #{v.inspect}" }.join("\n")
  end
end
