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
end
