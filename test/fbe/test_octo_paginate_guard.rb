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
class TestOctoPaginateGuard < Fbe::Test
  def test_guards_the_client_yielded_to_the_block
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":50}}', headers: { 'X-RateLimit-Remaining' => '50' } }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: '', headers: { 'X-RateLimit-Remaining' => '3' }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    assert_raises(Fbe::OffQuota) do
      o.with_disable_auto_paginate do |c|
        c.user(42)
        c.user(42)
      end
    end
  end
end
