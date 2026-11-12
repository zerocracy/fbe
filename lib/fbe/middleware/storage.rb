# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday/http_cache'
require 'json'
require_relative '../../fbe'
require_relative '../../fbe/middleware'

# Storage of responses for Faraday::HttpCache that leaves out what it can't serialize.
#
# A body that is not valid UTF-8 can't be turned into JSON, so such a response
# is not cached, and whatever was cached under its URL is dropped.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class Fbe::Middleware::Storage
  def initialize(**options)
    @origin = Faraday::HttpCache::Strategies::ByUrl.new(options)
  end

  def read(request)
    @origin.read(request)
  end

  def write(request, response)
    @origin.write(request, response)
  rescue JSON::GeneratorError
    @origin.delete(request.url)
  end

  def delete(url)
    @origin.delete(url)
  end
end
