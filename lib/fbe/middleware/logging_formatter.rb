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

# Faraday logging formatter show verbose log for only error response
class Fbe::Middleware::LoggingFormatter < Faraday::Logging::Formatter
  AUTHORIZATION_FILTER = [/(Authorization: )([^&]+)([^&]{5})/, '\1********\3'].freeze

  def initialize(**)
    super
    filter(*AUTHORIZATION_FILTER)
  end

  def request(env)
    super unless log_only_errors?
  end

  def response(env)
    return super unless log_only_errors?
    request_with_response(env) if env.status.nil? || env.status >= 400
  end

  def request_with_response(env)
    oll = @options[:log_level]
    @options[:log_level] = :error
    public_send(log_level, 'request') do
      "#{env.method.upcase} #{apply_filters(env.url.to_s)}"
    end
    log_headers('request', env.request_headers) if log_headers?(:request)
    log_body('request', env[:request_body]) if env[:request_body] && log_body?(:request)
    public_send(log_level, 'response') { "Status #{env.status}" }
    log_headers('response', env.response_headers) if log_headers?(:response)
    log_body('response', env[:response_body]) if env[:response_body] && log_body?(:response)
    @options[:log_level] = oll
    nil
  end

  def log_only_errors?
    @options[:log_only_errors]
  end
end
