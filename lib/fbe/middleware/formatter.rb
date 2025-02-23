# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday/logging/formatter'
require_relative '../../fbe'
require_relative '../../fbe/middleware'

# Faraday logging formatter show verbose log for only error response
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

  def shifted(txt)
    return '' if txt.nil?
    "  #{txt.gsub("\n", "\n  ")}"
  end

  def dump_headers(headers)
    return '' if headers.nil?
    headers.map { |k, v| "#{k}: #{v.inspect}" }.join("\n")
  end
end
