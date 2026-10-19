# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday/http_cache'
require 'json'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/storage'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class StorageTest < Fbe::Test
  def test_skips_response_it_cannot_serialize
    seed = Random.new_seed
    body = "\x89PNG".b + Random.new(seed).bytes(16) + "\xFF".b
    storage = Fbe::Middleware::Storage.new(serializer: JSON)
    request = Faraday::HttpCache::Request.new(method: :get, url: 'https://api.github.com/logo.png', headers: {})
    storage.write(request, Faraday::HttpCache::Response.new(status: 200, body:, response_headers: {}))
    assert_nil(storage.read(request), "response with a body of #{body.bytesize} raw bytes is cached (seed: #{seed})")
  end

  def test_drops_older_entry_of_url_it_cannot_store
    storage = Fbe::Middleware::Storage.new(serializer: JSON)
    request = Faraday::HttpCache::Request.new(method: :get, url: 'https://api.github.com/ёж', headers: {})
    storage.write(request, Faraday::HttpCache::Response.new(status: 200, body: 'ёж', response_headers: {}))
    storage.write(request, Faraday::HttpCache::Response.new(status: 200, body: "\xFF\xFE".b, response_headers: {}))
    assert_nil(storage.read(request), 'older response stays cached after a newer one could not be stored')
  end
end
