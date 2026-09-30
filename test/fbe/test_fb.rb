# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe'
require_relative '../../lib/fbe/fb'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestFb < Fbe::Test
  def test_simple
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::Buffer.new
    Fbe.fb.insert.foo = 1
    Fbe.fb.insert.bar = 2
    assert_equal(1, Fbe.fb.query('(exists bar)').each.to_a.size)
    stdout = $loog.to_s
    assert_includes(stdout, 'Inserted new fact #1', stdout)
  end

  def test_refuses_another_fb_for_the_same_global
    opts = Judges::Options.new
    global = {}
    first = Factbase.new
    decorated = Fbe.fb(fb: first, global:, options: opts, loog: Loog::NULL)
    assert_same(decorated, Fbe.fb(fb: first, global:, options: opts, loog: Loog::NULL))
    assert_same(decorated, Fbe.fb(fb: decorated, global:, options: opts, loog: Loog::NULL))
    assert_raises(Fbe::Error) { Fbe.fb(fb: Factbase.new, global:, options: opts, loog: Loog::NULL) }
    global.delete(:fb)
    second = Factbase.new
    Fbe.fb(fb: second, global:, options: opts, loog: Loog::NULL).insert.foo = 1
    assert_equal(1, Fbe.fb(fb: second, global:, options: opts, loog: Loog::NULL).size)
    assert_equal(0, first.size)
  end

  def test_defends_against_improper_facts
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::Buffer.new
    assert_raises(StandardError, 'issue without repository') do
      Fbe.fb.txn do |fbt|
        f = fbt.insert
        f.what = 'issue-was-opened'
        f.issue = 42
        f.where = 'github'
      end
    end
    assert_raises(StandardError, 'repository without where') do
      Fbe.fb.txn do |fbt|
        f = fbt.insert
        f.what = 'issue-was-opened'
        f.repository = 44
      end
    end
  end

  def test_defends_against_duplicates
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::Buffer.new
    assert_raises(StandardError) do
      Fbe.fb.insert.then do |f|
        f._id = 42
        f._id = 43
      end
    end
  end

  def test_sets_job
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new(job_id: 42)
    $loog = Loog::Buffer.new
    f = Fbe.fb.insert
    f.what = 'hello'
    f = Fbe.fb.query('(eq what "hello")').each.first
    assert_equal([42], f['_job'])
  end

  def test_increment_id_in_transaction
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::Buffer.new
    Fbe.fb.txn do |fbt|
      fbt.insert
      fbt.insert
    end
    arr = Fbe.fb.query('(always)').each.to_a
    assert_equal(1, arr[0]._id)
    assert_equal(2, arr[1]._id)
  end

  def test_adds_meta_properties
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new('JOB_ID' => 42)
    $loog = Loog::Buffer.new
    Fbe.fb.insert
    f = Fbe.fb.query('(always)').each.first
    refute_nil(f._id)
    refute_nil(f._time)
    refute_nil(f._version)
    refute_nil(f._job)
  end

  def test_dont_reuse_id_of_deleted_fact
    seed = Random.new_seed
    count = Random.new(seed).rand(2..16)
    fbx = Fbe.fb(fb: Factbase.new, global: {}, options: Judges::Options.new, loog: Loog::NULL)
    count.times { |i| fbx.insert.foo = i }
    fbx.query("(eq _id #{count})").delete!
    f = fbx.insert
    f.foo = 'ünïque'
    assert_equal(count + 1, f._id, "id of a deleted fact is given out again, seed #{seed}")
  end

  def test_dont_reuse_ids_when_every_fact_is_deleted
    seed = Random.new_seed
    count = Random.new(seed).rand(1..16)
    fbx = Fbe.fb(fb: Factbase.new, global: {}, options: Judges::Options.new, loog: Loog::NULL)
    count.times { |i| fbx.insert.foo = i }
    fbx.query('(always)').delete!
    f = fbx.insert
    f.foo = 'ünïque'
    assert_equal(count + 1, f._id, "numbering starts over after deleting every fact, seed #{seed}")
  end

  def test_numbers_after_highest_id_of_origin
    seed = Random.new_seed
    id = Random.new(seed).rand(1..1_000_000)
    fb = Factbase.new
    fb.insert._id = id
    fbx = Fbe.fb(fb:, global: {}, options: Judges::Options.new, loog: Loog::NULL)
    f = fbx.insert
    f.foo = 'ünïque'
    assert_equal(id + 1, f._id, "new fact does not follow the highest id of the origin, seed #{seed}")
  end

  def test_dont_reuse_id_of_fact_deleted_in_the_same_transaction
    seed = Random.new_seed
    count = Random.new(seed).rand(1..16)
    fbx = Fbe.fb(fb: Factbase.new, global: {}, options: Judges::Options.new, loog: Loog::NULL)
    count.times { |i| fbx.insert.foo = i }
    fbx.txn do |fbt|
      fbt.query("(eq _id #{count})").delete!
      fbt.insert.foo = 'ünïque'
    end
    assert_equal(
      [count + 1], fbx.query("(eq foo 'ünïque')").each.first['_id'],
      "id is given out twice in a transaction, seed #{seed}"
    )
  end
end
