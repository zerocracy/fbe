# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'faraday/logging/formatter'
require_relative '../../fbe'
require_relative '../../fbe/middleware'

# Faraday logging formatter shows verbose logs for error responses only
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Middleware::Formatter < Faraday::Logging::Formatter
  # Log HTTP request.
  #
  # @param [Hash] http The hash with data about HTTP request
  def request(http)
    @req = http
  end

  # Log HTTP response.
  #
  # @param [Hash] http The hash with data about HTTP response
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
