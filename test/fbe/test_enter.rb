# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock/minitest'
require_relative '../../lib/fbe/enter'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestEnter < Fbe::Test
  def test_simple
    WebMock.disable_net_connect!
    options = Judges::Options.new({ 'zerocracy_token' => '00000-0000-0000-00000', 'job_name' => 'test-product' })
    stub_request(:get, 'https://api.zerocracy.com/csrf').to_return(body: 'token')
    stub_request(:get, 'https://api.zerocracy.com/result?badge=foo').to_return(status: 204)
    stub_request(:post, 'https://api.zerocracy.com/valves')
      .with(body: '_csrf=token&badge=foo&pname=test-product&result=hi&why=no%20reason')
      .to_return(status: 302)
    assert_equal('hi', Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 'hi' })
  end

  def test_with_job_id
    WebMock.disable_net_connect!
    options = Judges::Options.new(
      { 'zerocracy_token' => '00000-0000-0000-00000', 'job_name' => 'test-product', 'job_id' => 42 }
    )
    stub_request(:get, 'https://api.zerocracy.com/csrf').to_return(body: 'token')
    stub_request(:get, 'https://api.zerocracy.com/result?badge=foo').to_return(status: 204)
    stub_request(:post, 'https://api.zerocracy.com/valves?job=42')
      .with(body: '_csrf=token&badge=foo&pname=test-product&result=hi&why=no%20reason')
      .to_return(status: 302)
    assert_equal('hi', Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 'hi' })
  end

  def test_same_type_on_miss_and_hit
    WebMock.disable_net_connect!
    options = Judges::Options.new({ 'zerocracy_token' => '00000-0000-0000-00000', 'job_name' => 'test-product' })
    stub_request(:get, 'https://api.zerocracy.com/csrf').to_return(body: 'token')
    stub_request(:get, 'https://api.zerocracy.com/result?badge=foo').to_return(status: 204)
    stub_request(:post, 'https://api.zerocracy.com/valves')
      .with(body: '_csrf=token&badge=foo&pname=test-product&result=42&why=no%20reason')
      .to_return(status: 302)
    miss = Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 42 }
    stub_request(:get, 'https://api.zerocracy.com/result?badge=foo').to_return(status: 200, body: '42')
    hit = Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 42 }
    assert_equal(miss.class, hit.class)
    assert_equal('42', miss)
    assert_equal('42', hit)
  end

  def test_in_testing_mode
    WebMock.enable_net_connect!
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('hi', Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 'hi' })
  end

  def test_rejects_an_absent_or_blank_project_name_before_doing_work
    WebMock.disable_net_connect!
    [nil, '', " \t "].each do |name|
      options = Judges::Options.new({ 'job_name' => name }.compact)
      ran = false
      error =
        assert_raises(Fbe::Error) do
          Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { ran = true }
        end
      assert_includes(error.message, 'job_name')
      refute(ran)
    end
    assert_not_requested(:any, %r{https://api.zerocracy.com/})
  end
end
