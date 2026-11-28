# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/same'
require_relative '../test__helper'

# Test for Fbe.same?.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestSame < Fbe::Test
  def test_returns_true_when_time_matches
    fb = Factbase.new
    fact = fb.insert
    now = Time.now
    fact.seen_at = now
    assert(Fbe.same?(fact, { seen_at: now }))
  end

  def test_returns_false_when_time_attribute_is_missing
    fb = Factbase.new
    fact = fb.insert
    fact.name = 'test_entry'
    refute(Fbe.same?(fact, { name: 'test_entry', finished_at: Time.now }))
  end

  def test_returns_false_when_time_attribute_differs
    fb = Factbase.new
    fact = fb.insert
    now = Time.now
    fact.seen_at = now
    refute(Fbe.same?(fact, { seen_at: now + 3600 }))
  end

  def test_ignores_non_time_attributes
    fb = Factbase.new
    fact = fb.insert
    now = Time.now
    fact.seen_at = now
    assert(Fbe.same?(fact, { seen_at: now, other_key: 'ignored_value' }))
  end

  def test_returns_true_with_empty_attrs
    fb = Factbase.new
    assert(Fbe.same?(fb.insert, {}))
  end

  def test_handles_multiple_times_matching
    fb = Factbase.new
    fact = fb.insert
    first = Time.now
    second = first + 60
    fact.started_at = first
    fact.finished_at = second
    assert(Fbe.same?(fact, { started_at: first, finished_at: second }))
  end

  def test_returns_false_when_one_of_multiple_times_is_missing
    fb = Factbase.new
    fact = fb.insert
    first = Time.now
    fact.started_at = first
    refute(Fbe.same?(fact, { started_at: first, finished_at: first + 60 }))
  end

  def test_works_with_string_keys
    fb = Factbase.new
    fact = fb.insert
    now = Time.now
    fact.checked_at = now
    assert(Fbe.same?(fact, { 'checked_at' => now }))
  end
end
