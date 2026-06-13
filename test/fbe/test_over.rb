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
    assert_includes(calls, { threshold: nil, resource: :search })
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
end
