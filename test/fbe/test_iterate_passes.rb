# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/iterate'
require_relative '../test__helper'

class TestIteratePasses < Fbe::Test
  def test_stops_between_passes_before_checking_the_repository_again
    fb = Factbase.new
    id = repository('foo/bar')
    add_item(fb, id, 1)
    add_item(fb, id, 2)
    visited = []
    stops = 0
    exhausted =
      lambda do |**|
        next false if visited.empty?
        stops += 1
        raise(RuntimeError, 'The iterator checked the budget again after the pass had stopped') if stops > 1
        true
      end
    Fbe.stub(:over?, exhausted) do
      scan(fb, 'foo/bar') do |_repo, n|
        visited << n
        n
      end
    end
    assert_equal([1], visited)
    assert_equal(1, stops)
  end

  def test_uses_the_first_of_two_markers_for_one_repository
    fb = Factbase.new
    id = repository('foo/bar')
    [4, 7].each do |before|
      marker = fb.insert
      marker.what = 'iterate'
      marker.where = 'github'
      marker.repository = id
      marker.last_item = before
    end
    [5, 8].each { |n| add_item(fb, id, n) }
    visited = []
    scan(fb, 'foo/bar') do |_repo, n|
      visited << n
      n
    end
    assert_equal([5, 8], visited)
  end

  def test_finishes_with_one_restarted_repository_and_one_at_its_repeat_limit
    fb = Factbase.new
    id = repository('foo/bar')
    [1, 2].each { |n| add_item(fb, id, n) }
    visited = []
    checks = 0
    budget =
      lambda do |**|
        checks += 1
        raise(RuntimeError, 'The iterator kept scanning after both repositories were done') if checks > 20
        false
      end
    Fbe.stub(:over?, budget) do
      scan(fb, 'foo/bar,foo/baz') do |repo, n|
        visited << [repo, n]
        n
      end
    end
    assert_equal([[id, 1], [id, 2]], visited)
  end

  private

  def repository(name)
    opts = Judges::Options.new({ 'testing' => true, 'repositories' => name })
    Fbe.octo(options: opts, global: {}, loog: Loog::NULL).repo_id_by_name(name)
  end

  def add_item(fb, repo, number)
    fact = fb.insert
    fact.repository = repo
    fact.num = number
  end

  def scan(fb, names, &visit)
    opts = Judges::Options.new({ 'testing' => true, 'repositories' => names })
    Fbe.iterate(fb:, options: opts, global: {}, loog: Loog::NULL) do
      as('last_item')
      by('(agg (and (eq repository $repository) (gt num $before)) (min num))')
      repeats(2)
      over(&visit)
    end
  end
end
