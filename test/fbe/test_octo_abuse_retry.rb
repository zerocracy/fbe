# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock'
require_relative '../../lib/fbe/octo'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestOctoAbuseRetry < Fbe::Test
  def test_retries_after_the_abuse_detection_answer
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 5000, limit: 5000 } }.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '5000' }
    )
    stub_request(:get, 'https://api.github.com/users/yegor256')
      .to_return(
        status: 403,
        body: { message: 'You have triggered an abuse detection mechanism' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      .then
      .to_return(
        status: 200, body: { login: 'yegor256' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    octo = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'github_token' => 'x' }))
    assert_equal('yegor256', octo.user('yegor256')[:login])
  end
end
