# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024-2025 Zerocracy
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
