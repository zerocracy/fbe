# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require_relative '../test__helper'
require_relative '../../lib/fbe/award'
require_relative '../../lib/fbe/bylaws'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestBylaws < Minitest::Test
  def test_simple
    laws = Fbe.bylaws
    assert_operator(laws.size, :>, 1)
    refute_nil(laws['published-release-was-rewarded'])
  end

  def test_check_all_bills
    awards = {
      'published-release-was-rewarded' => {
        { hoc: 0, contributors: 1 } => 24,
        { hoc: 10, contributors: 1 } => 24,
        { hoc: 100, contributors: 1 } => 24,
        { hoc: 500, contributors: 1 } => 29,
        { hoc: 1_000, contributors: 1 } => 32,
        { hoc: 10_000, contributors: 1 } => 32,
        { hoc: 30_000, contributors: 1 } => 32
      },
      'resolved-bug-was-rewarded' => {
        { hours: 1, self: 0 } => 8,
        { hours: 48, self: 0 } => 4,
        { hours: 80, self: 0 } => 4,
        { hours: 300, self: 0 } => 4,
        { hours: 3_000, self: 0 } => 4,
        { hours: 30_000, self: 0 } => 4,
        { hours: 1, self: 1 } => 4
      },
      'push-to-master-was-punished' => {
        {} => -16
      },
      'code-review-was-rewarded' => {
        { hoc: 0, comments: 0, self: 0 } => 4,
        { hoc: 3, comments: 0, self: 0 } => 4,
        { hoc: 78, comments: 7, self: 0 } => 4,
        { hoc: 600, comments: 1, self: 0 } => 4,
        { hoc: 500, comments: 40, self: 0 } => 17,
        { hoc: 5_000, comments: 100, self: 0 } => 24,
        { hoc: 100, comments: 50, self: 1 } => 4,
        { hoc: 10_000, comments: 200, self: 1 } => 4
      },
      'code-contribution-was-rewarded' => {
        { hoc: 0, comments: 0, reviews: 0 } => 4,
        { hoc: 3, comments: 0, reviews: 0 } => 4,
        { hoc: 78, comments: 0, reviews: 0 } => 4,
        { hoc: 78, comments: 1, reviews: 0 } => 4,
        { hoc: 50, comments: 15, reviews: 0 } => 4,
        { hoc: 50, comments: 25, reviews: 0 } => 4,
        { hoc: 180, comments: 7, reviews: 2 } => 13,
        { hoc: 199, comments: 8, reviews: 3 } => 14,
        { hoc: 150, comments: 5, reviews: 1 } => 8,
        { hoc: 500, comments: 25, reviews: 2 } => 4,
        { hoc: 99, comments: 6, reviews: 1 } => 4,
        { hoc: 1_500, comments: 3, reviews: 0 } => 4,
        { hoc: 15_000, comments: 40, reviews: 0 } => 4
      },
      'bug-report-was-rewarded' => {
        {} => 8
      },
      'enhancement-suggestion-was-rewarded' => {
        {} => 8
      },
      'dud-was-punished' => {
        {} => -16
      },
      'bad-branch-name-was-punished' => {
        {} => -12
      }
    }
    awards.each do |title, pairs|
      formula = Fbe.bylaws[title]
      refute_nil(formula, title)
      a = Fbe::Award.new(formula)
      help = [
        "  '#{title.tr('_', '-')}' => {\n    ",
        pairs.map do |args, _|
          [
            '{',
            args.empty? ? '' : "#{args.map { |k, v| " #{k}: #{v.to_s.gsub(/(?<!^)([0-9]{3})$/, '_\1')}" }.join(',')} ",
            "} => #{a.bill(args).points}"
          ].join
        end.join(",\n    "),
        "\n  },"
      ].join
      pairs.each do |args, points|
        b = a.bill(args)
        next if b.points == points
        raise \
          "Wrong reward of #{b.points} points from #{title}, " \
          "while #{points} expected (#{args}): #{b.greeting}\n\n#{help}"
      end
    end
  end
end
