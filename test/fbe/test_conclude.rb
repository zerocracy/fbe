# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'factbase/syntax'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/conclude'
require_relative '../../lib/fbe/fb'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestConclude < Fbe::Test
  def test_with_defaults
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    $judge = ''
    Fbe.conclude do
      # nothing
    end
  end

  def test_draw
    $fb = Factbase.new
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new
    $fb.insert.foo = 1
    $fb.insert.bar = 2
    Fbe.conclude(judge: 'judge-one') do
      on '(exists foo)'
      draw do |n, prev|
        n.sum = prev.foo + 1
        'Something funny and long enough to pass the requirements: long and long and long and long and long and long.'
      end
    end
    f = $fb.query('(exists sum)').each.to_a[0]
    assert_equal(2, f.sum)
    assert_equal('judge-one', f.what)
    assert_includes(f.details, 'funny')
  end

  def test_draw_with_rollback
    $fb = Factbase.new
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new
    $fb.insert.foo = 1
    Fbe.conclude(judge: 'judge-one') do
      on '(exists foo)'
      draw do |n, prev|
        n.hello = prev.foo
        throw :rollback
      end
    end
    assert_equal(1, $fb.size)
  end

  def test_consider
    fb = Factbase.new
    fb.insert.foo = 1
    options = Judges::Options.new
    Fbe.conclude(fb:, judge: 'issue-was-closed', loog: Loog::NULL, options:, global: {}) do
      on '(exists foo)'
      consider do |_prev|
        fb.insert.bar = 42
      end
    end
    f = fb.query('(exists bar)').each.to_a[0]
    assert_equal(42, f.bar)
  end

  def test_considers_until_quota
    WebMock.disable_net_connect!
    fb = Factbase.new
    5.times do
      fb.insert.foo = 1
    end
    options = Judges::Options.new
    stub_request(:get, %r{https://api.github.com/users/.*}).to_return(
      {
        body: { id: rand(100) }.to_json,
        headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '999' }
      },
      {
        body: { id: rand(100) }.to_json,
        headers: { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '9' }
      }
    )
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":51}}', headers: { 'X-RateLimit-Remaining' => '51' } }
    )
    global = {}
    o = Fbe.octo(loog: Loog::NULL, options:, global:)
    Fbe.conclude(fb:, judge: 'boom', loog: Loog::NULL, options:, global:) do
      quota_aware
      on '(exists foo)'
      consider do |f|
        f.bar = o.user("user-#{rand(100)}")[:id]
      end
    end
    assert_equal(2, fb.query('(exists bar)').each.to_a.size)
  end

  def test_ignores_globals
    $fb = nil
    $loog = nil
    $options = nil
    $global = nil
    fb = Factbase.new
    fb.insert.foo = 1
    Fbe.conclude(fb:, judge: 'judge-xxx', loog: Loog::NULL, global: {}, options: Judges::Options.new) do
      on '(exists foo)'
      draw do |n, prev|
        n.sum = prev.foo + 1
        'something funny'
      end
    end
    assert_equal(2, fb.size)
  end

  def test_stop_if_timeout_exceeded
    $fb = Factbase.new
    $fb.insert.then do |f|
      f._id = 1
      f.foo = 5
    end
    $fb.insert.then do |f|
      f._id = 2
      f.foo = 4
    end
    $fb.insert.then do |f|
      f._id = 3
      f.bar = 3
    end
    $fb.insert.then do |f|
      f._id = 4
      f.foo = 2
    end
    $fb.insert.then do |f|
      f._id = 5
      f.foo = 1
    end
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    $judge = ''
    total = 0
    now = Time.now
    time = Minitest::Mock.new
    time.expect(:now, now)
    time.expect(:now, now + 4)
    time.expect(:now, now + 8)
    time.expect(:now, now + 12)
    Fbe.conclude(time: time) do
      on '(exists foo)'
      timeout 10
      consider do |f|
        total += f.foo
      end
    end
    assert_equal(9, total)
    time.verify
  end
end
