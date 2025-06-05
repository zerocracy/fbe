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
    refute(o.off_quota)
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
    global = {}
    o = Fbe.octo(loog: Loog::NULL, global:, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { login: 'Dude56' }.to_json, headers: { 'Content-Type': 'application/json' }
    )
    nick = o.user_name_by_id(42)
    assert_equal('dude56', nick)
  end

  def test_reads_repo_name_by_id
    WebMock.disable_net_connect!
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
    global = {}
    o = Fbe.octo(loog: Loog::NULL, global:, options: Judges::Options.new)
    stub_request(:get, 'https://api.github.com/users/yegor256')
      .to_return(body: '{}', headers: { 'Cache-Control' => 'public, max-age=60', 'etag' => 'abc' })
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

  def test_off_quota
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: '{}', headers: { 'X-RateLimit-Remaining' => '333' }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: '', headers: { 'X-RateLimit-Remaining' => '3' }
    )
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    refute(o.off_quota)
    o.user(42)
    assert(o.off_quota)
  end

  def test_off_quota_twice
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: '{}', headers: { 'X-RateLimit-Remaining' => '333' }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      { body: '', headers: { 'X-RateLimit-Remaining' => '5555' } },
      { body: '', headers: { 'X-RateLimit-Remaining' => '5' } }
    )
    o = Fbe.octo(loog: Loog::VERBOSE, global: {}, options: Judges::Options.new)
    refute(o.off_quota)
    o.user(42)
    refute(o.off_quota)
    o.user(42)
    assert(o.off_quota)
  end

  def test_print_quota_left_while_initialize
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: '{}', headers: { 'X-RateLimit-Remaining' => '1234' }
    )
    buf = Loog::Buffer.new
    o = Fbe.octo(loog: buf, global: {}, options: Judges::Options.new({ 'github_token' => 'secret_github_token' }))
    assert_match(/Accessing GitHub API with a token \(19 chars, ending by "oken", 1234 quota remaining\)/, buf.to_s)
    assert_nil(o.last_response, 'Not to be requests until initialize main Octokit client, ' \
                                'because middleware cached after first request and not apply after')
  end

  def test_retrying
    WebMock.disable_net_connect!
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
    assert(o.off_quota)
    o.user('foo')
    refute(o.off_quota)
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
    WebMock.enable_net_connect!
    o = Fbe.octo(loog: Loog::VERBOSE, global: {}, options: Judges::Options.new({ 'github_api_pause' => 0.01 }))
    refute_nil(o.off_quota)
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
    stub_request(:get, 'https://api.github.com/user/123').to_return(
      status: 200,
      body: '{"id":123,"login":"test"}'
    )
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(
      status: 200,
      body: '{"id":456,"full_name":"foo/bar"}'
    )
    octo = Fbe.octo(loog:, global: {}, options: Judges::Options.new)
    octo.user(123)
    octo.repository('foo/bar')
    octo.repository('foo/bar')
    octo.print_trace!
    output = loog.to_s
    assert_includes output, 'GitHub API trace'
    assert_includes output, 'https://api.github.com/user/123: 1'
    assert_includes output, 'https://api.github.com/repos/foo/bar: 2'
    repo_index = output.index('https://api.github.com/repos/foo/bar: 2')
    user_index = output.index('https://api.github.com/user/123: 1')
    assert_operator repo_index, :<, user_index, 'URLs should be sorted by request count (highest first)'
  end

  def test_trace_gets_cleared_after_print
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/user/456').to_return(
      status: 200,
      body: '{"id":456,"login":"testuser"}'
    )
    first_loog = Loog::Buffer.new
    octo = Fbe.octo(loog: first_loog, global: {}, options: Judges::Options.new)
    octo.user(456)
    octo.print_trace!
    first_output = first_loog.to_s
    assert_includes first_output, 'GitHub API trace'
    second_loog = Loog::Buffer.new
    octo.instance_variable_set(:@loog, second_loog)
    octo.print_trace!
    second_output = second_loog.to_s
    assert_includes second_output, 'GitHub API trace is empty'
  end
end
