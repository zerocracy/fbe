# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require 'webmock/minitest'
require_relative '../../lib/fbe/octo'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestOcto < Fbe::Test
  def test_simple_use
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    o = Fbe.octo(loog: Loog::NULL, global:, options:)
    refute_predicate(o, :off_quota?)
    refute_nil(o.pull_request('foo/foo', 42))
    refute_nil(o.commit_pulls('foo/foo', 'sha'))
  end

  def test_post_comment
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    o = Fbe.octo(loog: Loog::NULL, global:, options:)
    assert_equal(42, o.add_comment('foo/foo', 4, 'hello!')[:id])
  end

  def test_give_repo_a_star
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    o = Fbe.octo(loog: Loog::NULL, global:, options:)
    assert(o.star('foo/foo'))
  end

  def test_detect_bot
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    o = Fbe.octo(loog: Loog::NULL, global:, options:)
    assert_equal('Bot', o.user(29_139_614)[:type])
    assert_equal('User', o.user('yegor256')[:type])
    assert_equal('User', o.user(42)[:type])
  end

  def test_rate_limit
    o = Fbe::FakeOctokit.new
    assert_equal(100, o.rate_limit.remaining)
  end

  def test_reads_nickname_by_id
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { login: 'Dude56' }.to_json, headers: { 'Content-Type': 'application/json' }
    )
    nick = o.user_name_by_id(42)
    assert_equal('dude56', nick)
  end

  def test_reads_repo_id_by_name
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(
      body: { id: 42 }.to_json, headers: { 'Content-Type': 'application/json' }
    )
    id = o.repo_id_by_name('foo/bar')
    assert_equal(42, id)
  end

  def test_reads_lost_repo_id_by_name
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(status: 404)
    assert_raises(StandardError) { o.repo_id_by_name('foo/bar') }
  end

  def test_fails_user_request_when_off_quota
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '3' } }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    assert_raises(StandardError) { o.user(42) }
  end

  def test_no_failure_on_printing_when_off_quota
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '3' } }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    o.print_trace!
  end

  def test_reads_repo_name_by_id
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    global = {}
    o = Fbe.octo(loog: Loog::NULL, global:, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(
      body: { full_name: 'Foo/bar56-Ff' }.to_json, headers: { 'Content-Type': 'application/json' }
    )
    nick = o.repo_name_by_id(42)
    assert_equal('foo/bar56-ff', nick)
  end

  def test_caching
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    global = {}
    o = Fbe.octo(loog: Loog::NULL, global:, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/users/yegor256')
      .to_return(
        body: '{}',
        headers: { 'Cache-Control' => 'public, max-age=60', 'etag' => 'abc', 'x-ratelimit-remaining' => '10000' }
      )
      .times(1)
      .then
      .to_raise('second request should be cached, not passed to GitHub API!')
    o.user('yegor256')
    o.user('yegor256')
  end

  def test_rate_limit_remaining
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: '', headers: { 'X-RateLimit-Remaining' => '4' }
    )
    o = Octokit::Client.new
    assert_equal(222, o.rate_limit.remaining)
    o.user(42)
    assert_equal(4, o.rate_limit.remaining)
    assert_equal(4, o.rate_limit.remaining)
  end

  def test_off_quota?
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":50}}', headers: { 'X-RateLimit-Remaining' => '50' } }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: '', headers: { 'X-RateLimit-Remaining' => '49' }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    refute_predicate(o, :off_quota?)
    o.user(42)
    assert_predicate(o, :off_quota?)
  end

  def test_off_quota_twice
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":51}}', headers: { 'X-RateLimit-Remaining' => '51' } }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      { body: '', headers: { 'X-RateLimit-Remaining' => '5555' } },
      { body: '', headers: { 'X-RateLimit-Remaining' => '5' } }
    )
    o = Fbe.octo(loog: Loog::VERBOSE, global: {}, options: Judges::Options.new)
    refute_predicate(o, :off_quota?)
    o.user(42)
    refute_predicate(o, :off_quota?)
    o.user(42)
    assert_predicate(o, :off_quota?)
  end

  def test_print_quota_left_while_initialize
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: '{}', headers: { 'X-RateLimit-Remaining' => '1234' }
    )
    buf = Loog::Buffer.new
    Fbe.octo(loog: buf, global: {}, options: Judges::Options.new({ 'github_token' => 'secret_github_token' }))
    assert_match(/Accessing GitHub API with a token \(19 chars, ending by "oken", 1234 quota remaining\)/, buf.to_s)
  end

  def test_retrying
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    global = {}
    o = Fbe.octo(loog: Loog::NULL, global:, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/users/yegor256')
      .to_raise(Octokit::TooManyRequests.new)
      .times(1)
      .then
      .to_return(body: '{}')
    o.user('yegor256')
  end

  def test_retrying_on_error_response
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    global = {}
    o = Fbe.octo(loog: Loog::NULL, global:, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/users/yegor256')
      .to_return(status: 503)
      .times(1)
      .then
      .to_return(body: '{}')
    o.user('yegor256')
  end

  def test_with_broken_token
    skip("it's a live test, run it manually if you need it")
    WebMock.enable_net_connect!
    global = {}
    options = Judges::Options.new({ 'github_token' => 'incorrect-value' })
    o = Fbe.octo(loog: Loog::NULL, global:, options:)
    assert_raises(StandardError) { o.repository('zerocracy/fbe') }
  end

  def test_workflow_run_usage
    WebMock.disable_net_connect!
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    assert_equal(53_000, o.workflow_run_usage('zerocracy/fbe', 1)[:run_duration_ms])
  end

  def test_commit_pulls
    skip("it's a live test, run it manually if you need it")
    WebMock.enable_net_connect!
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    assert_equal(1, o.commit_pulls('zerocracy/fbe', '0b7d0699bd744b62c0731064c2adaad0c58e1416').size)
    assert_equal(0, o.commit_pulls('zerocracy/fbe', '16b3ea6b71c6e932ba7666c40ca846ecaa6d6f0d').size)
  end

  def test_search_issues
    WebMock.disable_net_connect!
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    assert_equal(42, o.search_issues('repo:zerocracy/fbe type:issue').dig(:items, 0, :number))
    total_pr_count = 2
    assert_equal(total_pr_count, o.search_issues('repo:zerocracy/fbe type:pr')[:total_count])
    assert_equal(total_pr_count, o.search_issues('repo:zerocracy/fbe type:pr')[:items].count)
    unmereged_pr_count = 1
    assert_equal(unmereged_pr_count, o.search_issues('repo:zerocracy/fbe type:pr is:unmerged')[:total_count])
    assert_equal(unmereged_pr_count, o.search_issues('repo:zerocracy/fbe type:pr is:unmerged')[:items].count)
  end

  def test_pauses_when_quota_is_exceeded
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } },
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '1' } },
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '10000' } }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'github_api_pause' => 0.01 }))
    stub_request(:get, 'https://api.github.com/users/foo')
      .to_return(
        body: '{}',
        headers: { 'x-ratelimit-remaining' => '1' }
      )
      .to_return(
        body: '{}',
        headers: { 'x-ratelimit-remaining' => '10000' }
      )
    o.user('foo')
    assert_predicate(o, :off_quota?)
  end

  def test_fetches_fake_check_runs_for_ref
    WebMock.disable_net_connect!
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    sha = 'f2ca1bb6c7e907d06'
    result = o.check_runs_for_ref('zerocracy/baza', sha)
    assert_equal(7, result[:total_count])
    assert_equal(7, result[:check_runs].count)
    result = o.check_runs_for_ref('zerocracy/judges-action', sha)
    assert_equal(7, result[:total_count])
    assert_equal(7, result[:check_runs].count)
    result = o.check_runs_for_ref('zerocracy/something', sha)
    assert_equal(0, result[:total_count])
    assert_instance_of(Array, result[:check_runs])
    assert_equal(0, result[:check_runs].count)
  end

  def test_fetches_fake_workflow_run
    WebMock.disable_net_connect!
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    id = 10_438_531_072
    result = o.workflow_run('zerocracy/baza', id)
    assert_equal(id, result[:id])
    result = o.workflow_run('zerocracy/baza', 0)
    assert_equal(0, result[:id])
  end

  def test_fetches_fake_workflow_run_job
    WebMock.disable_net_connect!
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    id = 28_906_596_433
    result = o.workflow_run_job('zerocracy/baza', id)
    assert_equal(id, result[:id])
    result = o.workflow_run_job('zerocracy/baza', 0)
    assert_equal(0, result[:id])
  end

  def test_reads_quota
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    o = Fbe.octo(loog: Loog::VERBOSE, global: {}, options: Judges::Options.new({ 'github_api_pause' => 0.01 }))
    refute_nil(o.off_quota?)
  end

  def test_fetches_fake_not_found_users
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    assert_raises(Octokit::NotFound) { o.user(404_001) }
    assert_raises(Octokit::NotFound) { o.user(404_002) }
  end

  def test_fetches_fake_not_found_repos
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    assert_raises(Octokit::NotFound) { o.repository(404_123) }
    assert_raises(Octokit::NotFound) { o.repository(404_124) }
  end

  def test_fetches_fake_zerocracy_baza_repo
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    assert_equal('zerocracy/baza', o.repository(1439)[:full_name])
  end

  def test_fetches_fake_issue_events_has_assigned_event
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    result = o.issue_events('foo/foo', 123)
    assert_instance_of(Array, result)
    assert_equal(7, result.size)
    event = result.find { _1[:event] == 'assigned' }
    assert_equal(608, event[:id])
    assert_pattern do
      event => {
        id: Integer,
        actor: { login: 'user2', id: 422, type: 'User' },
        event: 'assigned',
        created_at: Time,
        assignee: { login: 'user2', id: 422, type: 'User' },
        assigner: { login: 'user', id: 411, type: 'User' }
      }
    end
  end

  def test_fetch_fake_issue_and_pr
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'testing' => true }))
    result = o.issue('yegor256/test', 142)
    assert_equal(Time.parse('2025-06-02 15:00:00 UTC'), result[:closed_at])
    assert_pattern do
      result => {
        id: 655,
        number: 142,
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        state: 'closed',
        created_at: Time,
        updated_at: Time,
        closed_at: Time
      }
    end
    result = o.issue('yegor256/test', 143)
    assert_equal(Time.parse('2025-06-01 18:20:00 UTC'), result[:closed_at])
    assert_pattern do
      result => {
        id: 656,
        number: 143,
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        state: 'closed',
        pull_request: { merged_at: nil },
        created_at: Time,
        updated_at: Time,
        closed_at: Time
      }
    end
  end

  def test_print_trace
    loog = Loog::Buffer.new
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } },
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } },
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/user/123').to_return do
      {
        status: 200,
        body: '{"id":123,"login":"test"}',
        headers: { 'X-RateLimit-Remaining' => '222' }
      }
    end
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return do
      {
        status: 200,
        body: '{"id":456,"full_name":"foo/bar"}',
        headers: { 'X-RateLimit-Remaining' => '222' }
      }
    end
    octo = Fbe.octo(loog:, global: {}, options: Judges::Options.new)
    octo.user(123)
    octo.repository('foo/bar')
    octo.repository('foo/bar')
    octo.print_trace!(all: true, max: 9_999)
    output = loog.to_s
    assert_includes output, '3 URLs vs 4 requests'
    assert_includes output, '219 quota left'
    assert_includes output, '/rate_limit: 1'
    assert_includes output, '/user/123: 1'
    assert_includes output, '/repos/foo/bar: 2'
    repo_index = output.index('/repos/foo/bar: 2')
    user_index = output.index('/user/123: 1')
    assert_operator repo_index, :<, user_index, 'URLs should be sorted by request count (highest first)'
  end

  def test_prints_only_real_requests
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub = stub_request(:get, 'https://api.github.com/user/123').to_return(
      status: 200,
      body: '{"id":123,"login":"test"}',
      headers: {
        'X-RateLimit-Remaining' => '222',
        'Content-Type' => 'application/json',
        'Cache-Control' => 'public, max-age=60, s-maxage=60',
        'Etag' => 'W/"2ff9dd4c3153f006830b2b8b721f6a4bb400a1eb81a2e1fa0a3b846ad349b9ec"',
        'Last-Modified' => 'Wed, 01 May 2025 20:00:00 GMT'
      }
    )
    Dir.mktmpdir do |dir|
      fcache = File.expand_path('test.db', dir)
      octo = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'sqlite_cache' => fcache }))
      octo.user(123)
      loog = Loog::Buffer.new
      octo = Fbe.octo(loog:, global: {}, options: Judges::Options.new({ 'sqlite_cache' => fcache }))
      WebMock.remove_request_stub(stub)
      octo.user(123)
      octo.print_trace!(all: true)
      refute_match('/user/123: 1', loog.to_s)
    end
  end

  def test_octo_not_trace_cached_requests
    WebMock.disable_net_connect!
    now = Time.now
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(
        status: 200, headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '5000' },
        body: { 'rate' => { 'limit' => 5000, 'remaining' => 5000, 'reset' => 1_672_531_200 } }.to_json
      )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/baza.rb')
      .to_return(
        status: 200,
        headers: {
          'date' => now.httpdate,
          'cache-control' => 'public, max-age=60, s-maxage=60',
          'last-modified' => (now - (6 * 60 * 60)).httpdate,
          'content-type' => 'application/json; charset=utf-8'
        },
        body: { id: 840_215_648, name: 'baza.rb' }.to_json
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
        body: { id: 840_215_648, name: 'baza.rb' }.to_json
      )
      .times(1)
      .then.to_raise('no more request to /repos/zerocracy/baza.rb')
    loog = Loog::Buffer.new
    o = Fbe.octo(loog:, global: {}, options: Judges::Options.new({}))
    o.print_trace!(all: true)
    Time.stub(:now, now) do
      5.times do
        o.repo('zerocracy/baza.rb')
      end
    end
    o.print_trace!(all: true)
    Time.stub(:now, now + 70) do
      25.times do
        o.repo('zerocracy/baza.rb')
      end
    end
    o.print_trace!(all: true)
    assert_requested :get, 'https://api.github.com/repos/zerocracy/baza.rb', times: 2
    output = loog.to_s
    assert_match('/repos/zerocracy/baza.rb: 1', output)
    refute_match('/repos/zerocracy/baza.rb: 5', output)
    refute_match('/repos/zerocracy/baza.rb: 25', output)
  end

  def test_trace_gets_cleared_after_print
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/user/456').to_return(
      status: 200,
      body: '{"id":456,"login":"testuser"}',
      headers: { 'X-RateLimit-Remaining' => '222' }
    )
    first_loog = Loog::Buffer.new
    octo = Fbe.octo(loog: first_loog, global: {}, options: Judges::Options.new)
    octo.user(456)
    octo.print_trace!
    first_output = first_loog.to_s
    assert_includes first_output, 'GitHub API trace'
  end

  def test_works_via_sqlite_store
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    Dir.mktmpdir do |dir|
      sqlite_cache = File.expand_path('test.db', dir)
      o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'sqlite_cache' => sqlite_cache }))
      stub = stub_request(:get, 'https://api.github.com/user/42').to_return(
        status: 200,
        body: { login: 'user1' }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Cache-Control' => 'public, max-age=60, s-maxage=60',
          'Etag' => 'W/"2ff9dd4c3153f006830b2b8b721f6a4bb400a1eb81a2e1fa0a3b846ad349b9ec"',
          'Last-Modified' => 'Wed, 01 May 2025 20:00:00 GMT'
        }
      )
      assert_equal('user1', o.user_name_by_id(42))
      WebMock.remove_request_stub(stub)
      o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'sqlite_cache' => sqlite_cache }))
      assert_equal('user1', o.user_name_by_id(42))
    end
  end

  def test_through_sqlite_store_when_broken_token
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    Dir.mktmpdir do |dir|
      file = File.expand_path('test.db', dir)
      stub_request(:get, 'https://api.github.com/user/4242').to_return(status: 401)
      o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'sqlite_cache' => file }))
      assert_raises(StandardError) do
        assert_equal('user1', o.user_name_by_id(4242))
      end
      assert_path_exists(file)
    end
  end

  def test_sqlite_store_for_use_in_different_versions
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    Dir.mktmpdir do |dir|
      stub =
        stub_request(:get, 'https://api.github.com/user/42')
          .to_return(
            status: 200,
            body: { login: 'user1' }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Cache-Control' => 'public, max-age=60, s-maxage=60',
              'Etag' => 'W/"2ff9dd4c3153f006830b2b8b721f6a4bb400a1eb81a2e1fa0a3b846ad349b9ec"',
              'Last-Modified' => 'Wed, 01 May 2025 20:00:00 GMT'
            }
          )
      sqlite_cache = File.expand_path('test.db', dir)
      Fbe.stub_const(:VERSION, '0.0.1') do
        o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'sqlite_cache' => sqlite_cache }))
        assert_equal('user1', o.user_name_by_id(42))
      end
      WebMock.remove_request_stub(stub)
      stub_request(:get, 'https://api.github.com/user/42')
        .to_return(
          status: 200,
          body: { login: 'user2' }.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'Cache-Control' => 'public, max-age=60, s-maxage=60',
            'Etag' => 'W/"2ff9dd4c3153f006830b2b8b721f6a4bb400a1eb81a2e1fa0a3b846ad349b9ec"',
            'Last-Modified' => 'Wed, 01 May 2025 20:00:00 GMT'
          }
        )
      Fbe.stub_const(:VERSION, '0.0.2') do
        o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new({ 'sqlite_cache' => sqlite_cache }))
        assert_equal('user2', o.user_name_by_id(42))
      end
    end
  end

  def test_fetch_rate_limit_by_making_new_request
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":321}}', headers: { 'X-RateLimit-Remaining' => '321' } }
    )
    loog = Loog::Buffer.new
    o = Fbe.octo(loog:, global: {}, options: Judges::Options.new)
    refute_predicate(o, :off_quota?)
    assert_match(/321 GitHub API quota left/, loog.to_s)
    o.print_trace!(all: true)
    assert_match(/321 quota left/, loog.to_s)
  end

  def test_throttling_request_to_rate_limit
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(
        status: 200, headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '5000' },
        body: { 'rate' => { 'limit' => 5000, 'remaining' => 5000, 'reset' => 1_672_531_200 } }.to_json
      )
      .then.to_return(
        status: 200, headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '4900' },
        body: { 'rate' => { 'limit' => 5000, 'remaining' => 4900, 'reset' => 1_672_531_200 } }.to_json
      )
      .then.to_return(
        status: 200, headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '4800' },
        body: { 'rate' => { 'limit' => 5000, 'remaining' => 4800, 'reset' => 1_672_531_200 } }.to_json
      )
      .then.to_raise('no more request to /rate_limit')
    stub_request(:get, 'https://api.github.com/user/1')
      .to_return(
        status: 200, headers: { 'Content-Type' => 'application/json' },
        body: { 'id' => 1, 'login' => 'user1' }.to_json
      ).times(1)
    stub_request(:get, 'https://api.github.com/user/111')
      .to_return(
        status: 200, headers: { 'Content-Type' => 'application/json' },
        body: { 'id' => 111, 'login' => 'user111' }.to_json
      )
      .times(201)
      .then.to_raise('no more request to /user/111')
    loog = Loog::Buffer.new
    o = Fbe.octo(loog:, global: {}, options: Judges::Options.new({}))
    o.user(1)
    o.print_trace!(all: true)
    201.times do
      o.user(111)
      o.rate_limit!.remaining
    end
    o.print_trace!(all: true)
    output = loog.to_s
    assert_requested :get, 'https://api.github.com/user/1', times: 1
    assert_requested :get, 'https://api.github.com/user/111', times: 201
    assert_requested :get, 'https://api.github.com/rate_limit', times: 3
    assert_match('2 URLs vs 2 requests', output)
    assert_match('/user/1: 1', output)
    assert_match('/rate_limit: 1', output)
    assert_match('2 URLs vs 203 requests', output)
    assert_match('/user/111: 201', output)
    assert_match('/rate_limit: 2', output)
  end

  def test_octo_http_cache_middleware_located_in_end_of_chain
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(
        status: 200, headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '5000' },
        body: { 'rate' => { 'limit' => 5000, 'remaining' => 5000, 'reset' => 1_672_531_200 } }.to_json
      )
    o = Fbe.octo(loog: fake_loog, global: {}, options: Judges::Options.new({}))
    assert_equal('Faraday::HttpCache', o.middleware.handlers.last.name, <<~MSG.strip.gsub!(/\s+/, ' '))
      Faraday::HttpCache middleware must be located in the end of chain middlewares,
      because the Oktokit client change Faraday::HttpCache position to the last,
      for more info, see: https://github.com/zerocracy/fbe/issues/230#issuecomment-3020551743 and
      https://github.com/octokit/octokit.rb/blob/ea3413c3174571e87c83d358fc893cc7613091fa/lib/octokit/connection.rb#L109-L119
    MSG
  end

  def test_octo_cache_still_available_on_duration_of_age
    WebMock.disable_net_connect!
    now = Time.now
    age = 60
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(
        status: 200, headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '5000' },
        body: { 'rate' => { 'limit' => 5000, 'remaining' => 5000, 'reset' => 1_672_531_200 } }.to_json
      )
    Dir.mktmpdir do |dir|
      sqlite_cache = File.expand_path('t.db', dir)
      o = Fbe.octo(loog: fake_loog, global: {}, options: Judges::Options.new({ 'sqlite_cache' => sqlite_cache }))
      stub_request(:get, 'https://api.github.com/repositories/798641472').to_return(
        status: 200,
        body: { id: 798_641_472, name: 'factbase' }.to_json,
        headers: {
          'Date' => now.httpdate,
          'Content-Type' => 'application/json; charset=utf-8',
          'Cache-Control' => "public, max-age=#{age}, s-maxage=#{age}",
          'Etag' => 'W/"f5f1ea995fd7266816f681aca5a81f539420c469070a47568bebdaa3055487bc"',
          'Last-Modified' => 'Fri, 04 Jul 2025 13:39:42 GMT'
        }
      ).times(1).then.to_raise('no more request to /repositories/798641472')
      assert_equal('factbase', o.repo(798_641_472)['name'])
      Time.stub(:now, now + age - 1) do
        assert_equal('factbase', o.repo(798_641_472)['name'])
      end
      stub_request(:get, 'https://api.github.com/repositories/798641472').to_return(
        status: 200,
        body: { id: 798_641_472, name: 'factbase_changed' }.to_json,
        headers: {
          'Date' => (now + age).httpdate,
          'Content-Type' => 'application/json; charset=utf-8',
          'Cache-Control' => "public, max-age=#{age}, s-maxage=#{age}",
          'Etag' => 'W/"f5f1ea995fd7266816f681aca5a81f539420c469070a47568bebdaa3055487be"',
          'Last-Modified' => 'Fri, 04 Jul 2025 13:39:42 GMT'
        }
      ).times(1).then.to_raise('no more request to /repositories/798641472')
      Time.stub(:now, now + age) do
        assert_equal('factbase_changed', o.repo(798_641_472)['name'])
      end
      Time.stub(:now, now + (2 * age) - 1) do
        assert_equal('factbase_changed', o.repo(798_641_472)['name'])
      end
    end
  end

  def test_octo_with_set_sqlite_cache_min_age
    WebMock.disable_net_connect!
    now = Time.now
    stub_request(:get, 'https://api.github.com/rate_limit')
      .to_return(
        status: 200, headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '5000' },
        body: { 'rate' => { 'limit' => 5000, 'remaining' => 5000, 'reset' => 1_672_531_200 } }.to_json
      )
    Dir.mktmpdir do |dir|
      sqlite_cache = File.expand_path('t.db', dir)
      options = Judges::Options.new({ 'sqlite_cache' => sqlite_cache, 'sqlite_cache_min_age' => 120 })
      o = Fbe.octo(loog: fake_loog, global: {}, options:)
      stub_request(:get, 'https://api.github.com/repositories/798641472').to_return(
        status: 200,
        body: { id: 798_641_472, name: 'factbase' }.to_json,
        headers: {
          'Date' => now.httpdate,
          'Content-Type' => 'application/json; charset=utf-8',
          'Cache-Control' => 'public, max-age=60, s-maxage=60',
          'Etag' => 'W/"f5f1ea995fd7266816f681aca5a81f539420c469070a47568bebdaa3055487bc"',
          'Last-Modified' => 'Fri, 04 Jul 2025 13:39:42 GMT'
        }
      ).times(1).then.to_raise('no more request to /repositories/798641472')
      Time.stub(:now, now) do
        assert_equal('factbase', o.repo(798_641_472)['name'])
      end
      Time.stub(:now, now + 50) do
        assert_equal('factbase', o.repo(798_641_472)['name'])
      end
      Time.stub(:now, now + 100) do
        assert_equal('factbase', o.repo(798_641_472)['name'])
      end
      stub_request(:get, 'https://api.github.com/repositories/798641472').to_return(
        status: 200,
        body: { id: 798_641_472, name: 'factbase_changed' }.to_json,
        headers: {
          'Date' => (now + 120).httpdate,
          'Content-Type' => 'application/json; charset=utf-8',
          'Cache-Control' => 'public, max-age=60, s-maxage=60',
          'Etag' => 'W/"f5f1ea995fd7266816f681aca5a81f539420c469070a47568bebdaa3055487bc"',
          'Last-Modified' => 'Fri, 04 Jul 2025 13:39:42 GMT'
        }
      )
      Time.stub(:now, now + 120) do
        assert_equal('factbase_changed', o.repo(798_641_472)['name'])
      end
    end
  end
end
