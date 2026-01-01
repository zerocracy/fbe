# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'faraday'
require 'faraday/http_cache'
require 'webmock'
require_relative '../../../lib/fbe'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/trace'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TraceTest < Fbe::Test
  def test_traces_successful_request
    trace = []
    stub_request(:get, 'http://example.com/test')
      .to_return(status: 200, body: 'success')
    conn =
      Faraday.new do |f|
        f.use Fbe::Middleware::Trace, trace
        f.adapter :net_http
      end
    conn.get('http://example.com/test')
    assert_equal 1, trace.size
    entry = trace.first
    assert_equal :get, entry[:method]
    assert_equal 'http://example.com/test', entry[:url]
    assert_equal 200, entry[:status]
    assert_instance_of Time, entry[:started_at]
    assert_instance_of Time, entry[:finished_at]
    assert_instance_of Float, entry[:duration]
    assert_operator entry[:duration], :>=, 0
    assert_operator entry[:finished_at], :>=, entry[:started_at]
  end

  def test_traces_multiple_requests
    trace = []
    stub_request(:get, 'http://example.com/endpoint1').to_return(status: 200)
    stub_request(:post, 'http://example.com/endpoint2').to_return(status: 201)
    stub_request(:delete, 'http://example.com/endpoint3').to_return(status: 404)
    conn =
      Faraday.new do |f|
        f.use Fbe::Middleware::Trace, trace
        f.adapter :net_http
      end
    conn.get('http://example.com/endpoint1')
    conn.post('http://example.com/endpoint2')
    conn.delete('http://example.com/endpoint3')
    assert_equal 3, trace.size
    assert_equal :get, trace[0][:method]
    assert_equal 200, trace[0][:status]
    assert_equal :post, trace[1][:method]
    assert_equal 201, trace[1][:status]
    assert_equal :delete, trace[2][:method]
    assert_equal 404, trace[2][:status]
  end

  def test_traces_error_responses
    trace = []
    stub_request(:get, 'http://example.com/error').to_return(status: 500, body: 'error')
    conn =
      Faraday.new do |f|
        f.use Fbe::Middleware::Trace, trace
        f.adapter :net_http
      end
    conn.get('http://example.com/error')
    assert_equal 1, trace.size
    entry = trace.first
    assert_equal 500, entry[:status]
    assert_equal 'http://example.com/error', entry[:url]
  end

  def test_handles_connection_errors
    trace = []
    stub_request(:get, 'http://example.com/timeout').to_timeout
    conn =
      Faraday.new do |f|
        f.use Fbe::Middleware::Trace, trace
        f.adapter :net_http
      end
    assert_raises(Faraday::ConnectionFailed) do
      conn.get('http://example.com/timeout')
    end
    assert_equal 0, trace.size
  end

  def test_preserves_request_with_query_params
    trace = []
    stub_request(:get, 'http://example.com/search').with(query: { 'q' => 'test', 'page' => '2' }).to_return(status: 200)
    conn =
      Faraday.new do |f|
        f.use Fbe::Middleware::Trace, trace
        f.adapter :net_http
      end
    conn.get('http://example.com/search?q=test&page=2')
    assert_equal 1, trace.size
    url = trace.first[:url]
    assert url.start_with?('http://example.com/search?')
    assert_includes url, 'q=test'
    assert_includes url, 'page=2'
  end

  def test_trace_and_cache_middlewares_together
    WebMock.disable_net_connect!
    now = Time.now
    stub_request(:get, 'https://api.example.com/page')
      .to_return(
        status: 200,
        headers: {
          'date' => now.httpdate,
          'cache-control' => 'public, max-age=60, s-maxage=60',
          'last-modified' => (now - (6 * 60 * 60)).httpdate
        },
        body: 'some body 1'
      )
      .times(1)
      .then
      .to_return(
        status: 200,
        headers: {
          'date' => (now + 70).httpdate,
          'cache-control' => 'public, max-age=60, s-maxage=60',
          'last-modified' => (now - (6 * 60 * 60)).httpdate,
          'content-type' => 'application/json; charset=utf-8'
        },
        body: 'some body 2'
      )
      .times(1)
      .then.to_raise('no more request to /page')
    trace_real = []
    trace_full = []
    builder =
      Faraday::RackBuilder.new do |f|
        f.use Fbe::Middleware::Trace, trace_full
        f.use(Faraday::HttpCache, serializer: Marshal, shared_cache: false, logger: Loog::NULL)
        f.use Fbe::Middleware::Trace, trace_real
        f.adapter :net_http
      end
    conn = Faraday::Connection.new(builder: builder)
    5.times do
      r = conn.get('https://api.example.com/page')
      assert_equal('some body 1', r.body)
    end
    assert_equal(1, trace_real.size)
    assert_equal(5, trace_full.size)
    trace_real.clear
    trace_full.clear
    5.times do
      r = conn.get('https://api.example.com/page')
      assert_equal('some body 1', r.body)
    end
    assert_equal(0, trace_real.size)
    assert_equal(5, trace_full.size)
    Time.stub(:now, now + 70) do
      5.times do
        r = conn.get('https://api.example.com/page')
        assert_equal('some body 2', r.body)
      end
    end
    assert_equal(1, trace_real.size)
    assert_equal(10, trace_full.size)
  end
end
