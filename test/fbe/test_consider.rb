# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/consider'
require_relative '../../lib/fbe/fb'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestConsider < Fbe::Test
  def test_with_simple_query
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '3' } }
    )
    $fb = Factbase.new
    $fb.insert.foo = 42
    $epoch = Time.now
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    $judge = ''
    Fbe.consider('(always)') do |f|
      f.bar = 7
    end
    assert_equal(1, $fb.size)
  end

  def test_quota_unaware
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '0' } }
    )
    $fb = Factbase.new
    $fb.insert.foo = 42
    $epoch = Time.now
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    $judge = ''
    Fbe.consider('(always)', quota_aware: false) do |f|
      f.bar = 7
    end
    assert_equal(1, $fb.size)
  end

  def test_stops_before_timeout_overrun_with_raised_slot
    seed = Random.new_seed
    fb = Factbase.new
    fb.insert.foo = Random.new(seed).rand(1..999)
    Fbe.consider(
      '(exists foo)',
      fb:, judge: 'судья-таймаут', global: {}, loog: Loog::NULL,
      options: Judges::Options.new('timeout=10'), epoch: Time.now, kickoff: Time.now - 5,
      quota_aware: false, slot: Random.new(seed).rand(6..600)
    ) { |f| f.bar = 7 }
    assert_empty(fb.query('(exists bar)').each.to_a, "raised slot did not stop the loop, seed #{seed}")
  end

  def test_stops_before_lifetime_overrun_with_raised_slot
    seed = Random.new_seed
    fb = Factbase.new
    fb.insert.foo = Random.new(seed).rand(1..999)
    Fbe.consider(
      '(exists foo)',
      fb:, judge: 'судья-жизнь', global: {}, loog: Loog::NULL,
      options: Judges::Options.new('lifetime=10'), epoch: Time.now - 5, kickoff: Time.now,
      quota_aware: false, slot: Random.new(seed).rand(6..600)
    ) { |f| f.bar = 7 }
    assert_empty(fb.query('(exists bar)').each.to_a, "raised slot did not stop the loop, seed #{seed}")
  end

  def test_processes_fact_when_slot_fits_the_timeout
    seed = Random.new_seed
    fb = Factbase.new
    fb.insert.foo = Random.new(seed).rand(1..999)
    Fbe.consider(
      '(exists foo)',
      fb:, judge: 'judge-fits', global: {}, loog: Loog::NULL,
      options: Judges::Options.new('timeout=10'), epoch: Time.now, kickoff: Time.now - 5,
      quota_aware: false, slot: Random.new(seed).rand(1..4)
    ) { |f| f.bar = 7 }
    assert_equal(1, fb.query('(exists bar)').each.to_a.size, "fitting slot stopped the loop, seed #{seed}")
  end

  def test_ignores_raised_slot_when_timeout_unaware
    seed = Random.new_seed
    fb = Factbase.new
    fb.insert.foo = Random.new(seed).rand(1..999)
    Fbe.consider(
      '(exists foo)',
      fb:, judge: 'judge-unaware', global: {}, loog: Loog::NULL,
      options: Judges::Options.new('timeout=10'), epoch: Time.now, kickoff: Time.now - 5,
      quota_aware: false, timeout_aware: false, slot: Random.new(seed).rand(6..600)
    ) { |f| f.bar = 7 }
    assert_equal(1, fb.query('(exists bar)').each.to_a.size, "slot stopped a timeout unaware loop, seed #{seed}")
  end
end
