# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe'
require_relative '../../lib/fbe/fb'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
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
end
