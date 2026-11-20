# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/regularly'
require_relative '../test__helper'

class TestRegularlyBoundaries < Fbe::Test
  def test_rejects_a_nil_area
    error = assert_raises(Fbe::Error) { run_regularly(area: nil) }
    assert_equal('The area is nil', error.message)
  end

  def test_rejects_a_nil_interval_property
    error = assert_raises(Fbe::Error) { run_regularly(property: nil) }
    assert_equal('The p_every_days is nil', error.message)
  end

  def test_rejects_a_nil_factbase
    error = assert_raises(Fbe::Error) { run_regularly(fb: nil) }
    assert_equal('The fb is nil', error.message)
  end

  def test_rejects_a_nil_judge
    error = assert_raises(Fbe::Error) { run_regularly(judge: nil) }
    assert_equal('The $judge is not set', error.message)
  end

  def test_rejects_a_nil_logger
    error = assert_raises(Fbe::Error) { run_regularly(loog: nil) }
    assert_equal('The $loog is not set', error.message)
  end

  def test_omits_since_when_no_history_property_was_requested
    fact = nil
    Fbe.regularly('quality', 'interval', fb: Factbase.new, judge: 'test', loog: Loog::NULL) { |f| fact = f }
    refute_includes(fact.all_properties, 'since')
  end

  def test_waits_until_the_default_interval_is_complete
    assert_equal(0, runs_after((7 * 86_400) - 1))
  end

  def test_runs_at_the_default_seven_day_boundary
    assert_equal(1, runs_after(7 * 86_400))
  end

  private

  def run_regularly(area: 'quality', property: 'interval', fb: Factbase.new, judge: 'test', loog: Loog::NULL)
    Fbe.regularly(area, property, fb:, judge:, loog:) { |_| flunk('invalid arguments reached the block') }
  end

  def runs_after(age)
    now = Time.utc(2026, 1, 15)
    fb = Factbase.new
    marker = fb.insert
    marker.what = 'regularly'
    marker.judge = 'test'
    marker.when = now - age
    runs = 0
    environment = ENV.method(:fetch)
    ENV.stub(:fetch, ->(key, *args) { key == 'TODAY' ? now.iso8601 : environment.call(key, *args) }) do
      Fbe.regularly('quality', 'interval', fb:, judge: 'test', loog: Loog::NULL) { runs += 1 }
    end
    runs
  end
end
