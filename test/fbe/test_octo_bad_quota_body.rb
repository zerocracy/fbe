# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'judges/options'
require 'loog'
require 'webmock'
require_relative '../../lib/fbe/octo'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestOctoBadQuotaBody < Fbe::Test
  def test_survives_a_rate_limit_body_that_is_not_json
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      status: 200, body: 'not-json-at-all{{{',
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '4999' }
    )
    log = Loog::Buffer.new
    Fbe.octo(loog: log, global: {}, options: Judges::Options.new({ 'github_token' => 'x' }))
    assert_includes(log.to_s, 'quota unknown')
  end
end
