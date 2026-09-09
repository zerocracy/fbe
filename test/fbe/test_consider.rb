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

  def test_reserves_configured_slot
    outcomes = { 6 => [], 5 => [7] }
    %w[timeout lifetime].each do |budget|
      outcomes.each do |slot, expected|
        fb = Factbase.new
        fb.insert.foo = 42
        now = Time.utc(2024, 1, 1)
        Time.stub(:now, now) do
          Fbe.consider(
            '(exists foo)', fb:, judge: 'test', global: {}, loog: Loog::NULL,
                            options: Judges::Options.new("#{budget}=10"), epoch: now - 5, kickoff: now - 5,
                            quota_aware: false, slot:
          ) { |f| f.bar = 7 }
        end
        assert_equal(expected, fb.query('(exists foo)').each.first['bar'] || [])
      end
    end
  end

  def test_preserves_default_slot_and_disabled_limits
    [{}, { slot: 6, timeout_aware: false, lifetime_aware: false }].each do |settings|
      fb = Factbase.new
      fb.insert.foo = 42
      now = Time.utc(2024, 1, 1)
      Time.stub(:now, now) do
        Fbe.consider(
          '(exists foo)', fb:, judge: 'test', global: {}, loog: Loog::NULL,
                          options: Judges::Options.new('timeout=10,lifetime=10'), epoch: now - 5, kickoff: now - 5,
                          quota_aware: false, **settings
        ) { |f| f.bar = 7 }
      end
      assert_equal(7, fb.query('(exists foo)').each.first.bar)
    end
  end
end
