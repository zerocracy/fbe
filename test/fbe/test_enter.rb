# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock/minitest'
require_relative '../../lib/fbe/enter'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestEnter < Fbe::Test
  def test_simple
    WebMock.disable_net_connect!
    options = Judges::Options.new({ 'zerocracy_token' => '00000-0000-0000-00000' })
    stub_request(:get, 'https://api.zerocracy.com/csrf')
      .to_return(body: 'token')
    stub_request(:get, 'https://api.zerocracy.com/valves/result?badge=foo')
      .to_return(status: 204)
    stub_request(:post, 'https://api.zerocracy.com/valves/add?job=0')
      .with(body: '_csrf=token&badge=foo&name&pname&result=hi&why=no%20reason')
      .to_return(status: 302)
    assert_equal('hi', Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 'hi' })
  end

  def test_in_testing_mode
    WebMock.enable_net_connect!
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('hi', Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 'hi' })
  end
end
