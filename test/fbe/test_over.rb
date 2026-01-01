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

  def test_check_off_quota_disabled
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    loog = Loog::NULL
    Fbe.octo(loog:, options:, global:).stub(:off_quota?, true) do
      refute(Fbe.over?(global:, options:, loog:, quota_aware: false))
    end
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
