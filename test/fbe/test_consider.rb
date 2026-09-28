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
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '5000' } }
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
    assert_equal(1, $fb.query('(eq bar 7)').each.to_a.size, 'block was not applied to the fact')
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
    assert_equal(1, $fb.query('(eq bar 7)').each.to_a.size, 'block was not applied despite exhausted quota')
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

  def test_skips_facts_when_off_quota
    WebMock.disable_net_connect!
    seed = Random.new_seed
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => Random.new(seed).rand(0..99).to_s } }
    )
    fb = Factbase.new
    fb.insert.foo = Random.new(seed).rand(1..999)
    Fbe.consider(
      '(exists foo)',
      fb:, judge: 'судья-квота', global: {}, loog: Loog::NULL,
      options: Judges::Options.new, epoch: Time.now, kickoff: Time.now
    ) { |f| f.bar = 7 }
    assert_empty(fb.query('(exists bar)').each.to_a, "block ran while off quota, seed #{seed}")
  end

  def test_applies_block_to_every_matched_fact
    seed = Random.new_seed
    fb = Factbase.new
    count = Random.new(seed).rand(2..40)
    count.times { |i| fb.insert.foo = "факт-#{i}" }
    Fbe.consider(
      '(exists foo)',
      fb:, judge: 'judge-every', global: {}, loog: Loog::NULL,
      options: Judges::Options.new, epoch: Time.now, kickoff: Time.now, quota_aware: false
    ) { |f| f.bar = 7 }
    assert_equal(count, fb.query('(eq bar 7)').each.to_a.size, "some matched facts were skipped, seed #{seed}")
  end

  def test_leaves_unmatched_facts_untouched
    seed = Random.new_seed
    fb = Factbase.new
    fb.insert.foo = Random.new(seed).rand(1..999)
    fb.insert.baz = "ünmatched-#{Random.new(seed).hex(8)}"
    Fbe.consider(
      '(exists foo)',
      fb:, judge: 'judge-unmatched', global: {}, loog: Loog::NULL,
      options: Judges::Options.new, epoch: Time.now, kickoff: Time.now, quota_aware: false
    ) { |f| f.bar = 7 }
    assert_empty(fb.query('(and (exists baz) (exists bar))').each.to_a, "unmatched fact was changed, seed #{seed}")
  end
end
