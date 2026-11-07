# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'factbase/sync/sync_factbase'
require 'judges/options'
require 'timeout'
require_relative '../../lib/fbe/tombstone'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestTombstone < Fbe::Test
  def test_keeps_concurrent_burials_from_distinct_instances
    additions = [3, 5]
    [false, true].each do |decorated|
      fb =
        if decorated
          Fbe.fb(fb: Factbase.new, global: {}, options: Judges::Options.new(testing: true), loog: fake_loog)
        else
          Factbase::SyncFactbase.new(Factbase.new)
        end
      Fbe::Tombstone.new(fb: fb).bury!('github', 42, 1)
      arrived = Queue.new
      release = Queue.new
      transaction = fb.method(:txn)
      delayed =
        lambda do |&block|
          arrived << true
          release.pop
          transaction.call(&block)
        end
      fb.stub(:txn, delayed) do
        workers =
          additions.map do |issue|
            Thread.new { Fbe::Tombstone.new(fb: fb).bury!('github', 42, issue) }
          end
        begin
          Timeout.timeout(5) do
            2.times { arrived.pop }
            2.times { release << true }
            workers.each(&:value)
          end
        ensure
          2.times { release << true }
          workers.each(&:join)
        end
      end
      assert_equal([1, 3, 5], Fbe::Tombstone.new(fb: fb).issues('github', 42).sort)
      assert_equal(1, fb.query('(eq what "tombstone")').each.to_a.size)
    end
  end

  def test_rolls_back_ranges_and_preserves_metadata
    fb = Fbe.fb(fb: Factbase.new, global: {}, options: Judges::Options.new(testing: true), loog: fake_loog)
    tombstone = Fbe::Tombstone.new(fb: fb)
    tombstone.bury!('github', 42, 1)
    fact = fb.query('(eq what "tombstone")').each.first
    before = fact.all_properties.to_h { |key| [key, fact[key].to_a] }
    transaction = fb.method(:txn)
    failing =
      lambda do |&block|
        transaction.call do |current|
          block.call(current)
          raise(Fbe::Error, 'abort burial')
        end
      end
    fb.stub(:txn, failing) do
      assert_raises(Fbe::Error) { tombstone.bury!('github', 42, 3) }
    end
    assert_equal([1], tombstone.issues('github', 42))
    tombstone.bury!('github', 42, 3)
    after = fb.query('(eq what "tombstone")').each.first
    assert_equal(before.except('issues'), (after.all_properties - ['issues']).to_h { |key| [key, after[key].to_a] })
    assert_equal([1, 3], tombstone.issues('github', 42).sort)
  end

  def test_simple
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    ts.bury!(where, 41, 13)
    ts.bury!(where, 42, 13)
    ts.bury!(where, 42, 999)
    assert(ts.has?(where, 41, 13))
    assert(ts.has?(where, 42, 999))
    refute(ts.has?(where, 8, 7))
    refute(ts.has?(where, 43, 999))
    refute(ts.has?(where, 43, 990))
  end

  def test_on_empty
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    refute(ts.has?(where, 8, 7))
  end

  def test_bury_twice
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    2.times { ts.bury!(where, 42, 7) }
    assert(ts.has?(where, 42, 7))
  end

  def test_list_all_issues
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    ts.bury!(where, 42, 7)
    ts.bury!(where, 42, 8)
    ts.bury!(where, 42, 66)
    all = ts.issues(where, 42)
    assert_equal(3, all.size)
    assert_includes(all, 7)
    assert_includes(all, 8)
    assert_includes(all, 66)
    refute_includes(all, 9)
  end

  def test_merges_them
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    where = 'github'
    ts.bury!(where, 42, 13)
    ts.bury!(where, 42, 18)
    ts.bury!(where, 42, 14)
    ts.bury!(where, 42, [17, 15, 16])
    assert(ts.has?(where, 42, 16))
    assert(ts.has?(where, 42, [16, 18]))
    refute(ts.has?(where, 42, 22))
  end

  def test_merge_complex_ranges
    where = 'github'
    repo = 42
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.what = 'tombstone'
      f.where = where
      f.repository = repo
      Fbe.overwrite(f, 'issues', %w[4-4 4-5 5-6 5-5 4-6 10-14], fb:)
    end
    ts = Fbe::Tombstone.new(fb:)
    ts.bury!(where, repo, 5)
    f = fb.query('(always)').each.first
    assert_equal(%w[4-6 10-14], f['issues'])
    Fbe.overwrite(f, 'issues', %w[14-15 8-8 4-5 4-4 5-6 5-5 4-6 10-13], fb:)
    ts.bury!(where, repo, 20)
    assert_equal(%w[4-6 8 10-15 20], fb.query('(always)').each.first['issues'])
  end

  def test_uses_large_random_range
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    arg = nil
    callable =
      lambda do |n|
        arg = n
        42
      end
    SecureRandom.stub(:random_number, callable) do
      ts.bury!('github', 42, 1)
      ts.bury!('github', 43, 1)
      ts.bury!('github', 44, 1)
    end
    assert_equal(9_999_999_999_999, arg, 'the SecureRandom range must be the large 10T value to avoid _id collisions')
    ids = fb.query("(and (eq what 'tombstone'))").map { |f| f[:_id] }
    ids.uniq!
    assert_equal(1, ids.size, 'stubbed random_number returns same value, all get same _id')
  end

  def test_store_single_issues_without_turning_them_into_pairs
    where = 'github'
    repo = 42
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.what = 'tombstone'
      f.where = where
      f.repository = repo
      Fbe.overwrite(f, 'issues', %w[207 209-209 211-211 214-214 216-220 224-224 227-227 230], fb:)
    end
    ts = Fbe::Tombstone.new(fb:)
    ts.bury!(where, repo, 226)
    f = fb.query('(always)').each.first
    assert_equal(%w[207 209 211 214 216-220 224 226-227 230], f['issues'])
    assert(ts.has?(where, repo, 216))
    assert(ts.has?(where, repo, 217))
    assert(ts.has?(where, repo, 218))
    assert(ts.has?(where, repo, 220))
    refute(ts.has?(where, repo, 206))
    refute(ts.has?(where, repo, 215))
    refute(ts.has?(where, repo, 221))
    refute(ts.has?(where, repo, 231))
  end

  def test_empty_list_is_not_buried
    fb = Factbase.new
    ts = Fbe::Tombstone.new(fb:)
    ts.bury!('github', 42, 5)
    refute(ts.has?('github', 42, []))
    refute(ts.has?('github', 43, []))
  end

  def test_cannot_bury_string_member
    seed = Random.new_seed
    member = "ж#{Random.new(seed).rand(1..10_000)}"
    tombstone = Fbe::Tombstone.new(fb: Factbase.new)
    assert_raises(Fbe::Error, "string member #{member.inspect} is buried, seed is #{seed}") do
      tombstone.bury!('github', 42, [7, member])
    end
  end

  def test_cannot_bury_nil_member
    seed = Random.new_seed
    repo = Random.new(seed).rand(1..10_000)
    tombstone = Fbe::Tombstone.new(fb: Factbase.new)
    assert_raises(Fbe::Error, "nil member is buried in repo #{repo}, seed is #{seed}") do
      tombstone.bury!('github', repo, [nil])
    end
  end

  def test_cannot_check_string_member
    seed = Random.new_seed
    member = "ж#{Random.new(seed).rand(1..10_000)}"
    tombstone = Fbe::Tombstone.new(fb: Factbase.new)
    tombstone.bury!('github', 42, 7)
    assert_raises(Fbe::Error, "string member #{member.inspect} is checked, seed is #{seed}") do
      tombstone.has?('github', 42, [7, member])
    end
  end

  def test_cannot_check_nil_member
    seed = Random.new_seed
    repo = Random.new(seed).rand(1..10_000)
    tombstone = Fbe::Tombstone.new(fb: Factbase.new)
    tombstone.bury!('github', repo, 7)
    assert_raises(Fbe::Error, "nil member is checked in repo #{repo}, seed is #{seed}") do
      tombstone.has?('github', repo, [nil])
    end
  end

  def test_cannot_check_negative_member
    seed = Random.new_seed
    member = -Random.new(seed).rand(1..10_000)
    tombstone = Fbe::Tombstone.new(fb: Factbase.new)
    tombstone.bury!('github', 42, 7)
    assert_raises(Fbe::Error, "negative member #{member} is checked, seed is #{seed}") do
      tombstone.has?('github', 42, [member])
    end
  end

  def test_dont_touch_factbase_when_member_is_invalid
    seed = Random.new_seed
    member = "ж#{Random.new(seed).rand(1..10_000)}"
    fb = Factbase.new
    begin
      Fbe::Tombstone.new(fb:).bury!('github', 42, [member])
    rescue Fbe::Error
      nil
    end
    assert_equal(0, fb.size, "factbase is touched by member #{member.inspect}, seed is #{seed}")
  end
end
