# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/fbe/just_one'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestJustOne < Fbe::Test
  def test_tells_apart_two_times_inside_one_second
    fb = Factbase.new
    early = Time.utc(2026, 9, 17, 20, 6, 10, 100_000)
    late = Time.utc(2026, 9, 17, 20, 6, 10, 900_000)
    Fbe.just_one(fb:) do |f|
      f.what = 'thing'
      f.when = early
    end
    Fbe.just_one(fb:) do |f|
      f.what = 'thing'
      f.when = late
    end
    assert_equal(2, fb.size)
  end

  def test_ignores
    fb = Factbase.new
    before = fb.insert
    before._id = 42
    before.foo = 'hello dude'
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 'hello dude'
      end
    assert_equal(1, fb.size)
    assert_equal(before._id, n._id)
  end

  def test_injects
    fb = Factbase.new
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 42
      end
    assert_equal(42, n.foo)
  end

  def test_ignores_system_attributes_when_matching
    fb = Factbase.new
    before = fb.insert
    before._id = 42
    before.foo = 'hello dude'
    n =
      Fbe.just_one(fb:) do |f|
        f._id = 99
        f.foo = 'hello dude'
      end
    assert_equal(1, fb.size)
    assert_equal(before._id, n._id)
  end

  def test_raises_on_empty_value
    assert_raises(StandardError) do
      Fbe.just_one(fb: Factbase.new) do |f|
        f.foo = ''
      end
    end
  end

  def test_raises_on_nil
    assert_raises(StandardError) do
      Fbe.just_one(fb: Factbase.new) do |f|
        f.foo = nil
      end
    end
  end

  def test_raises_without_block
    assert_raises(Fbe::Error, 'just_one accepted a call without a block') do
      Fbe.just_one(fb: Factbase.new)
    end
  end

  def test_dont_insert_fact_without_block
    fb = Factbase.new
    begin
      Fbe.just_one(fb:)
    rescue Fbe::Error
      nil
    end
    assert_equal(0, fb.size, 'just_one inserted a fact without a block')
  end

  def test_reuses_existing_fact_with_multiple_attributes
    fb = Factbase.new
    first =
      Fbe.just_one(fb:) do |f|
        f._id = 1
        f.what = 'issue'
        f.repo = 'zerocracy/fbe'
        f.issue_id = 42
      end
    assert_equal(1, fb.size)
    second =
      Fbe.just_one(fb:) do |f|
        f.what = 'issue'
        f.repo = 'zerocracy/fbe'
        f.issue_id = 42
      end
    assert_equal(1, fb.size)
    assert_equal(first._id, second._id)
    assert_equal('zerocracy/fbe', second.repo)
  end

  def test_creates_new_fact_when_attributes_differ
    fb = Factbase.new
    first =
      Fbe.just_one(fb:) do |f|
        f._id = 1
        f.what = 'issue'
        f.issue_id = 42
      end
    second =
      Fbe.just_one(fb:) do |f|
        f._id = 2
        f.what = 'issue'
        f.issue_id = 43
      end
    assert_equal(2, fb.size)
    refute_equal(first._id, second._id)
  end

  def test_creates_new_fact_when_additional_attribute_requested
    fb = Factbase.new
    first =
      Fbe.just_one(fb:) do |f|
        f._id = 1
        f.what = 'issue'
      end
    second =
      Fbe.just_one(fb:) do |f|
        f._id = 2
        f.what = 'issue'
        f.repo = 'zerocracy/fbe'
      end
    assert_equal(2, fb.size)
    refute_equal(first._id, second._id)
  end

  def test_reuses_fact_with_time_attribute
    fb = Factbase.new
    time = Time.utc(2026, 10, 16, 12, 0, 0, 500_000)
    first =
      Fbe.just_one(fb:) do |f|
        f._id = 1
        f.what = 'event'
        f.when = time
      end
    second =
      Fbe.just_one(fb:) do |f|
        f.what = 'event'
        f.when = time
      end
    assert_equal(1, fb.size)
    assert_equal(first._id, second._id)
  end

  def test_reuses_fact_with_special_characters_in_strings
    fb = Factbase.new
    first =
      Fbe.just_one(fb:) do |f|
        f._id = 1
        f.text = 'hello "world" and \'quotes\''
      end
    second =
      Fbe.just_one(fb:) do |f|
        f.text = 'hello "world" and \'quotes\''
      end
    assert_equal(1, fb.size)
    assert_equal(first._id, second._id)
  end

  def test_retains_existing_attributes_on_reuse
    fb = Factbase.new
    before = fb.insert
    before._id = 42
    before.foo = 'bar'
    before.extra = 999
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 'bar'
      end
    assert_equal(1, fb.size)
    assert_equal(before._id, n._id)
    assert_equal(999, n.extra)
  end
end
