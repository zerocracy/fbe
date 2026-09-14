# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock/minitest'
require_relative '../../lib/fbe/octo'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestOctoRedirects < Fbe::Test
  def test_follows_a_renamed_repository
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/repos/old/name').to_return(
      status: 301, headers: { 'Location' => 'https://api.github.com/repos/new/name' }
    )
    stub_request(:get, 'https://api.github.com/repos/new/name').to_return(
      body: '{"id":777,"full_name":"new/name"}', headers: { 'Content-Type' => 'application/json' }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    assert_equal(777, o.repository('old/name')[:id])
  end
end
