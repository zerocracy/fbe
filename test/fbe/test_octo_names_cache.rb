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
class TestOctoNamesCache < Fbe::Test
  def test_asks_github_about_a_repository_once
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    req =
      stub_request(:get, 'https://api.github.com/repositories/777').to_return(
        body: '{"id":777,"full_name":"foo/bar"}', headers: { 'Content-Type' => 'application/json' }
      )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    5.times { assert_equal('foo/bar', o.repo_name_by_id(777)) }
    assert_requested(req, times: 1)
  end
end
