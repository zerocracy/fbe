# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/iterate'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestIterate < Fbe::Test
  def test_simple
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    fb.insert.foo = 42
    Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global: {}, epoch: Time.now, kickoff: Time.now) do
      as 'labels_were_scanned'
      by '(agg (always) (max foo))'
      repeats 2
      over do |_repository, foo|
        f = fb.insert
        f.foo = foo + 1
        f.foo
      end
    end
    assert_equal(4, fb.size)
  end

  def test_stops_on_timeout
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true', 'lifetime=1'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    fb.insert.foo = 42
    Fbe.iterate(fb:, loog: Loog::VERBOSE, options: opts, global: {}, epoch: Time.now - 60, kickoff: Time.now) do
      as 'labels_were_scanned'
      by '(agg (always) (max foo))'
      repeats 2
      over do |i|
        sleep 999
        i
      end
    end
    assert_equal(1, fb.size)
  end

  def test_many_repeats
    opts = Judges::Options.new(['repositories=foo/bar,foo/second', 'testing=true'])
    cycles = 0
    reps = 5
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
      as 'labels_were_scanned'
      by '(plus 1 1)'
      repeats reps
      over do |_, nxt|
        cycles += 1
        nxt
      end
    end
    assert_equal(reps * 2, cycles)
  end

  def test_with_restart
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    cycles = 0
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    f = fb.insert
    f.foo = 42
    Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
      as 'labels_were_scanned'
      by '(agg (and (eq foo 42) (not (exists bar))) (max foo))'
      repeats 10
      over do |_, nxt|
        cycles += 1
        f.bar = 1
        nxt
      end
    end
    assert_equal(1, cycles)
  end

  def test_quota_aware_continues_when_quota_available
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    cycles = 0
    Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
      as 'quota_test'
      by '(plus 1 1)'
      repeats 5
      over do |_, nxt|
        cycles += 1
        nxt + 1
      end
    end
    assert_equal(5, cycles)
  end

  def test_raises_when_label_not_set
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        by '(plus 1 1)'
        over { |_, nxt| nxt }
      end
    end
  end

  def test_raises_when_label_not_in_snake_case
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        as 'kebab-case'
        by '(plus 1 1)'
        over { |_, nxt| nxt }
      end
    end
  end

  def test_raises_when_query_not_set
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        as 'no_query_test'
        over { |_, nxt| nxt }
      end
    end
  end

  def test_raises_when_block_returns_non_integer
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        as 'non_integer_test'
        by '(plus 1 1)'
        over { |_, _| 'not-an-integer' }
      end
    end
  end

  def test_raises_when_label_set_twice
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        as 'first_label'
        as 'second_label'
      end
    end
  end

  def test_raises_when_query_set_twice
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        by '(plus 1 1)'
        by '(plus 2 2)'
      end
    end
  end

  def test_raises_when_repeats_is_nil
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        as 'nil_repeats_test'
        by '(plus 1 1)'
        repeats nil
      end
    end
  end

  def test_raises_when_repeats_is_not_positive
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        as 'zero_repeats_test'
        by '(plus 1 1)'
        repeats 0
      end
    end
  end

  def test_raises_when_label_is_nil
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        as nil
      end
    end
  end

  def test_raises_when_query_is_nil
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    assert_raises(StandardError) do
      Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
        by nil
      end
    end
  end

  def test_persists_marker_facts
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    fb.insert.num = 10
    Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
      as 'marker_test'
      by '(agg (always) (max num))'
      repeats 1
      over do |_, nxt|
        nxt + 5
      end
    end
    markers = fb.query("(and (eq what 'iterate') (eq where 'github'))").each.to_a
    assert_equal(1, markers.size)
    assert_equal(15, markers.first.marker_test)
  end

  def test_multiple_repositories_with_different_progress
    opts = Judges::Options.new(['repositories=foo/bar,foo/baz', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    results = []
    Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
      as 'multi_repo_test'
      by '(plus 1 1)'
      repeats 2
      over do |repo, nxt|
        results << [repo, nxt]
        nxt + 1
      end
    end
    assert_equal(4, results.size)
  end

  def test_all_repos_restart_causes_exit
    opts = Judges::Options.new(['repositories=foo/bar,foo/baz', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    cycles = 0
    restarts = 0
    Fbe.iterate(fb:, loog: Loog::NULL, global: {}, options: opts, epoch: Time.now, kickoff: Time.now) do
      as 'all_restart_test'
      by '(agg (eq foo 123) (first foo))'
      repeats 10
      over do |_, nxt|
        cycles += 1
        restarts += 1 if nxt.nil?
        nxt || 0
      end
    end
    assert_equal(0, cycles)
    assert_equal(0, restarts)
  end

  def test_all_markers_in_one_fact
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    fb.insert.foo = 42
    Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global: {}, epoch: Time.now, kickoff: Time.now) do
      as 'first_marker'
      by '(agg (always) (max foo))'
      over do |_repository, foo|
        f = fb.insert
        f.foo = foo + 1
        f.foo
      end
    end
    Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global: {}, epoch: Time.now, kickoff: Time.now) do
      as 'second_marker'
      by '(agg (always) (max foo))'
      over do |_repository, foo|
        f = fb.insert
        f.foo = foo + 1
        f.foo
      end
    end
    fb.query("(eq what 'iterate')").each.first.then do |f|
      refute_nil(f)
      assert_equal('github', f.where)
      assert_equal(680, f.repository)
      assert_equal(43, f.first_marker)
      assert_equal(44, f.second_marker)
    end
  end

  def test_all_markers_in_one_exists_fact
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: opts, loog: Loog::NULL)
    fb.insert.then do |f|
      f.what = 'iterate'
      f.where = 'github'
      f.repository = 680
      f.first_marker = 40
      f.second_marker = 20
    end
    fb.insert.foo = 42
    Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global: {}, epoch: Time.now, kickoff: Time.now) do
      as 'first_marker'
      by '(agg (always) (max foo))'
      over do |_repository, foo|
        f = fb.insert
        f.foo = foo + 1
        f.foo
      end
    end
    fb.query("(eq what 'iterate')").each.first.then do |f|
      refute_nil(f)
      assert_equal('github', f.where)
      assert_equal(680, f.repository)
      assert_equal(43, f.first_marker)
      assert_equal(20, f.second_marker)
    end
    Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global: {}, epoch: Time.now, kickoff: Time.now) do
      as 'second_marker'
      by '(agg (always) (max foo))'
      over do |_repository, foo|
        foo + 7
      end
    end
    fb.query("(eq what 'iterate')").each.first.then do |f|
      refute_nil(f)
      assert_equal('github', f.where)
      assert_equal(680, f.repository)
      assert_equal(43, f.first_marker)
      assert_equal(50, f.second_marker)
    end
  end

  def test_sort_by_configuration
    opts = Judges::Options.new(['repositories=foo/bar', 'testing=true'])
    global = {}
    fb = Fbe.fb(fb: Factbase.new, global:, options: opts, loog: Loog::NULL)
    fb.insert.then do |f|
      f.what = 'iterate'
      f.where = 'github'
      f.repository = 680
      f.marker = 3
    end
    20.times do |i|
      fb.insert.then do |f|
        f.where = 'github'
        f.what = 'judge'
        f.repository = 680
        f.issue = i + 1
        f.prop = 'prop' if i.even?
      end
    end
    ex =
      assert_raises(RuntimeError) do
        Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global:, epoch: Time.now, kickoff: Time.now) do
          sort_by nil
        end
      end
    assert_equal('Cannot set sort field to nil', ex.message)
    ex =
      assert_raises(RuntimeError) do
        Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global:, epoch: Time.now, kickoff: Time.now) do
          sort_by :issue
        end
      end
    assert_equal('Sort field must be a String', ex.message)
    ex =
      assert_raises(RuntimeError) do
        Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global:, epoch: Time.now, kickoff: Time.now) do
          sort_by 'issue'
          sort_by 'item'
        end
      end
    assert_equal('Sort field is already set', ex.message)
    Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global:, epoch: Time.now, kickoff: Time.now) do
      as 'marker'
      sort_by 'issue'
      by "(and
            (gt issue $before)
            (eq repository $repository)
            (eq where 'github')
            (eq what 'judge')
            (empty (and (exists prop) (eq issue $issue))))"
      repeats 100
      over do |repository, issue|
        f =
          Fbe.if_absent(fb:, always: true) do |n|
            n.where = 'github'
            n.what = 'judge'
            n.issue = issue
            n.repository = repository
          end
        f.prop2 = 'prop2'
        issue
      end
    end
    assert_equal(9, fb.query('(and (eq what "judge") (exists prop2))').each.to_a.size)
    assert_equal(3, fb.query('(eq what "iterate")').each.to_a.first.marker)
    Fbe.iterate(fb:, loog: Loog::NULL, options: opts, global:, epoch: Time.now, kickoff: Time.now) do
      as 'marker'
      sort_by 'issue'
      by "(and
            (gt issue $before)
            (eq repository $repository)
            (eq where 'github')
            (eq what 'judge')
            (empty (and (exists prop) (eq issue $issue))))"
      repeats 5
      over do |repository, issue|
        f =
          Fbe.if_absent(fb:, always: true) do |n|
            n.where = 'github'
            n.what = 'judge'
            n.issue = issue
            n.repository = repository
          end
        f.prop3 = 'prop3'
        issue
      end
    end
    assert_equal(5, fb.query('(and (eq what "judge") (exists prop3))').each.to_a.size)
    assert_equal(12, fb.query('(eq what "iterate")').each.to_a.first.marker)
  end

  def test_catch_fbe_off_quota_exception_correctly
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":103}}', headers: { 'X-RateLimit-Remaining' => '103' } }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(
      body: { id: 42 }.to_json, headers: { 'Content-Type': 'application/json' }
    ).times(3).then.to_raise(StandardError.new('No more https://api.github.com/repos/foo/bar'))
    stub_request(:get, 'https://api.github.com/repos/foo/baz').to_return(
      body: { id: 43 }.to_json, headers: { 'Content-Type': 'application/json' }
    ).times(1000).then.to_raise(StandardError.new('No more https://api.github.com/repos/foo/baz'))
    global = {}
    loog = Loog::NULL
    options = Judges::Options.new(['repositories=foo/bar'])
    octo = Fbe.octo(options:, global:, loog:)
    fb = Fbe.fb(fb: Factbase.new, global:, options:, loog:)
    fb.insert.foo = 42
    count = 0
    Fbe.iterate(fb:, loog:, global:, options:, epoch: Time.now, kickoff: Time.now) do
      as 'marker'
      by '(agg (always) (max foo))'
      over do |_repository, foo|
        1000.times do
          octo.repository('foo/baz')
          count += 1
        end
        foo
      end
    end
    assert_equal(51, count)
  end

  def test_with_exhausted_rate_limit
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":0}}', headers: { 'X-RateLimit-Remaining' => '0' } }
    )
    global = {}
    loog = Loog::NULL
    options = Judges::Options.new(['repositories=foo/bar'])
    octo = Fbe.octo(options:, global:, loog:)
    fb = Fbe.fb(fb: Factbase.new, global:, options:, loog:)
    fb.insert.foo = 42
    count = 0
    Fbe.iterate(fb:, loog:, global:, options:, epoch: Time.now, kickoff: Time.now) do
      as 'marker'
      by '(agg (always) (max foo))'
      over do |_repository, foo|
        octo.repository('foo/baz')
        count += 1
        foo
      end
    end
    assert_equal(0, count)
  end
end
