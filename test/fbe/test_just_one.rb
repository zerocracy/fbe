# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'factbase/sync/sync_factbase'
require_relative '../../lib/fbe/just_one'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestJustOne < Fbe::Test
  def test_ignores
    fb = Factbase.new
    fb.insert.foo = 'hello dude'
    n =
      Fbe.just_one(fb:) do |f|
        f.foo = 'hello dude'
      end
    refute_nil(n)
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
    fb.insert.foo = 'hello dude'
    n =
      Fbe.just_one(fb:) do |f|
        f._id = 42
        f.foo = 'hello dude'
      end
    refute_nil(n)
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

  def test_inserts_only_one_fact_concurrently
    fb = Factbase::SyncFactbase.new(Factbase.new)
    threads =
      Array.new(2) do
        Thread.new do
          Fbe.just_one(fb:) do |f|
            f.kind = 'once'
            f.key = 'same'
          end
        end
      end
    threads.each(&:join)
    assert_equal(1, fb.query("(and (eq kind 'once') (eq key 'same'))").each.count)
  end
end
