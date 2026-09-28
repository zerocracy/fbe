# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/octo'
require_relative '../../lib/fbe/over'
require_relative '../test__helper'

# Test.
class TestOver < Fbe::Test
  def test_simple
    refute(Fbe.over?(global: {}, options: Judges::Options.new({ 'testing' => true }), loog: Loog::NULL))
  end

  def test_check_off_quota_enabled
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    loog = Loog::NULL
    Fbe.octo(loog:, options:, global:).stub(:off_quota?, true) do
      assert(Fbe.over?(global:, options:, loog:, quota_aware: true))
    end
  end

  def test_check_search_off_quota_enabled
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    loog = Loog::NULL
    octo = Fbe.octo(loog:, options:, global:)
    calls = []
    octo.define_singleton_method(:off_quota?) do |*args, **kwargs|
      kwargs = args.last if kwargs.empty? && args.last.is_a?(Hash)
      call = { threshold: kwargs[:threshold], resource: kwargs.fetch(:resource, :core) }
      calls << call
      call[:resource] == :search
    end
    assert(Fbe.over?(global:, options:, loog:, quota_aware: true))
    assert_includes(calls, { threshold: 100, resource: :core })
    assert_includes(calls, { threshold: 10, resource: :search })
  end

  def test_check_off_quota_disabled
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    loog = Loog::NULL
    Fbe.octo(loog:, options:, global:).stub(:off_quota?, true) do
      refute(Fbe.over?(global:, options:, loog:, quota_aware: false))
    end
  end

  def test_search_quota_stops_run_when_core_has_quota
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    loog = Loog::NULL
    octo = Fbe.octo(loog:, options:, global:)
    def octo.off_quota?(resource: :core, **)
      resource == :search
    end
    assert(Fbe.over?(global:, options:, loog:, quota_aware: true))
  end

  def test_check_lifetime_enabled
    global = {}
    options = Judges::Options.new({ 'testing' => true, 'lifetime' => 100 })
    loog = Loog::NULL
    assert(Fbe.over?(global:, options:, loog:, epoch: Time.now - 120, lifetime_aware: true))
  end

  def test_check_lifetime_disabled
    global = {}
    options = Judges::Options.new({ 'testing' => true, 'lifetime' => 100 })
    loog = Loog::NULL
    refute(Fbe.over?(global:, options:, loog:, epoch: Time.now - 120, lifetime_aware: false))
  end

  def test_check_timeout_enabled
    global = {}
    options = Judges::Options.new({ 'testing' => true, 'timeout' => 100 })
    loog = Loog::NULL
    assert(Fbe.over?(global:, options:, loog:, kickoff: Time.now - 120, timeout_aware: true))
  end

  def test_check_timeout_disabled
    global = {}
    options = Judges::Options.new({ 'testing' => true, 'timeout' => 100 })
    loog = Loog::NULL
    refute(Fbe.over?(global:, options:, loog:, kickoff: Time.now - 120, timeout_aware: false))
  end

  def test_stops_when_nine_tenths_of_lifetime_are_spent
    seed = Random.new_seed
    lifetime = Random.new(seed).rand(100..10_000)
    options = Judges::Options.new({ 'testing' => true, 'lifetime' => lifetime })
    assert(
      Fbe.over?(
        global: {}, options:, loog: Loog::NULL, epoch: Time.now - (lifetime * 0.95), kickoff: Time.now,
        quota_aware: false, lifetime_aware: true, timeout_aware: false
      ),
      "the run went on with 95% of #{lifetime}s lifetime spent, seed #{seed}"
    )
  end

  def test_goes_on_while_lifetime_is_mostly_left
    seed = Random.new_seed
    lifetime = Random.new(seed).rand(100..10_000)
    options = Judges::Options.new({ 'testing' => true, 'lifetime' => lifetime })
    refute(
      Fbe.over?(
        global: {}, options:, loog: Loog::NULL, epoch: Time.now - (lifetime * 0.8), kickoff: Time.now,
        quota_aware: false, lifetime_aware: true, timeout_aware: false
      ),
      "the run stopped with 80% of #{lifetime}s lifetime spent, seed #{seed}"
    )
  end

  def test_stops_when_nine_tenths_of_timeout_are_spent
    seed = Random.new_seed
    timeout = Random.new(seed).rand(100..10_000)
    options = Judges::Options.new({ 'testing' => true, 'timeout' => timeout })
    assert(
      Fbe.over?(
        global: {}, options:, loog: Loog::NULL, epoch: Time.now, kickoff: Time.now - (timeout * 0.95),
        quota_aware: false, lifetime_aware: false, timeout_aware: true
      ),
      "the run went on with 95% of #{timeout}s timeout spent, seed #{seed}"
    )
  end

  def test_goes_on_while_timeout_is_mostly_left
    seed = Random.new_seed
    timeout = Random.new(seed).rand(100..10_000)
    options = Judges::Options.new({ 'testing' => true, 'timeout' => timeout })
    refute(
      Fbe.over?(
        global: {}, options:, loog: Loog::NULL, epoch: Time.now, kickoff: Time.now - (timeout * 0.8),
        quota_aware: false, lifetime_aware: false, timeout_aware: true
      ),
      "the run stopped with 80% of #{timeout}s timeout spent, seed #{seed}"
    )
  end

  def test_refuses_a_missing_context
    opts = Judges::Options.new({ 'testing' => true })
    assert_raises(Fbe::Error) do
      Fbe.over?(global: nil, options: opts, loog: Loog::NULL, quota_aware: false)
    end
    assert_raises(Fbe::Error) do
      Fbe.over?(global: {}, options: nil, loog: Loog::NULL, quota_aware: false)
    end
    assert_raises(Fbe::Error) do
      Fbe.over?(global: {}, options: opts, loog: nil, quota_aware: false)
    end
  end
end
