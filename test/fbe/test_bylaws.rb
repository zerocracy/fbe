# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require_relative '../../lib/fbe/award'
require_relative '../../lib/fbe/bylaws'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestBylaws < Fbe::Test
  def test_simple
    laws = Fbe.bylaws
    assert_operator(laws.size, :>, 1)
    refute_nil(laws['published-release-was-rewarded'])
  end

  def test_apostrophes_are_not_double_escaped
    Fbe.bylaws.each do |title, formula|
      markdown = Fbe::Award.new(formula).bylaw.markdown
      refute_match(
        /\\'/,
        markdown,
        "Bylaw #{title.inspect} contains a backslash-escaped apostrophe in: #{markdown.inspect}"
      )
    end
  end

  def test_comments_penalty_counts_above_the_threshold
    a = Fbe::Award.new(Fbe.bylaws['code-contribution-was-rewarded'])
    assert_equal(
      a.bill({ hoc: 150, comments: 8, reviews: 1 }).points - 8,
      a.bill({ hoc: 150, comments: 48, reviews: 1 }).points
    )
  end

  def test_cannot_bill_without_a_declared_input
    ignored =
      Fbe.bylaws.to_h do |title, formula|
        inputs = formula.scan(/\(in ([a-z_0-9]+)\s/).flatten
        [title, inputs.select { |input| billable?(formula, inputs - [input]) }]
      end.reject { |_, inputs| inputs.empty? }
    assert_empty(ignored, "these bylaws bill without the inputs they declare: #{ignored.inspect}")
  end

  def test_bills_with_declared_inputs_only
    broken = Fbe.bylaws.reject { |_, formula| billable?(formula, formula.scan(/\(in ([a-z_0-9]+)\s/).flatten) }
    assert_empty(broken.keys, "these bylaws need inputs they dont declare: #{broken.keys.inspect}")
  end

  def test_rewards_a_larger_team_more
    seed = Random.new_seed
    team = Random.new(seed).rand(2..4)
    a = Fbe::Award.new(Fbe.bylaws['published-release-was-rewarded'])
    assert_operator(
      a.bill(hoc: 0, contributors: team).points, :>,
      a.bill(hoc: 0, contributors: 1).points,
      "a release by #{team} contributors is not worth more than a release by one (seed: #{seed})"
    )
  end

  def test_check_all_bills
    awards = {
      'published-release-was-rewarded' => {
        { hoc: 0, contributors: 0 } => 24,
        { hoc: 0, contributors: 1 } => 26,
        { hoc: 0, contributors: 4 } => 32,
        { hoc: 10, contributors: 1 } => 26,
        { hoc: 100, contributors: 2 } => 28,
        { hoc: 500, contributors: 1 } => 31,
        { hoc: 1_000, contributors: 1 } => 32,
        { hoc: 10_000, contributors: 1 } => 32,
        { hoc: 30_000, contributors: 50 } => 32
      },
      'resolved-bug-was-rewarded' => {
        { hours: 1, self: 0 } => 12,
        { hours: 48, self: 0 } => 6,
        { hours: 80, self: 0 } => 5,
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
        { hoc: 78, comments: 7, self: 0 } => 12,
        { hoc: 120, comments: 4, self: 0 } => 4,
        { hoc: 600, comments: 1, self: 0 } => 8,
        { hoc: 500, comments: 40, self: 0 } => 24,
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
        { hoc: 180, comments: 7, reviews: 2 } => 24,
        { hoc: 199, comments: 8, reviews: 3 } => 24,
        { hoc: 150, comments: 5, reviews: 1 } => 24,
        { hoc: 500, comments: 25, reviews: 2 } => 8,
        { hoc: 99, comments: 6, reviews: 1 } => 16,
        { hoc: 200, comments: 0, reviews: 1 } => 8,
        { hoc: 542, comments: 0, reviews: 1 } => 8,
        { hoc: 799, comments: 0, reviews: 1 } => 8,
        { hoc: 800, comments: 0, reviews: 1 } => 4,
        { hoc: 1_500, comments: 3, reviews: 0 } => 4,
        { hoc: 15_000, comments: 40, reviews: 0 } => 4
      },
      'bug-report-was-rewarded' => {
        {} => 12
      },
      'enhancement-suggestion-was-rewarded' => {
        {} => 12
      },
      'dud-was-punished' => {
        {} => -16
      },
      'bad-branch-name-was-punished' => {
        {} => -12
      },
      'long-pull-was-punished' => {
        {} => -8
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
        raise(
          Fbe::Error,
          "Wrong reward of #{b.points} points from #{title}, " \
          "while #{points} expected (#{args}): #{b.greeting}\n\n#{help}"
        )
      end
    end
  end

  def test_never_renders_a_negative_number_in_the_text
    Fbe.bylaws(anger: 2, love: 2, paranoia: 2).each do |title, formula|
      md = Fbe::Award.new(formula).bylaw.markdown
      assert_empty(md.scan(/\*\*-[0-9.]+\*\*/), "The text of '#{title}' states a negative number: #{md}")
    end
  end

  def test_returns_s_expressions
    Fbe.bylaws.each_value do |formula|
      assert_match(/\A\(award\b/, formula.strip)
    end
  end

  def billable?(formula, inputs)
    Fbe::Award.new(formula).bill(inputs.to_h { |input| [input.to_sym, 1] })
    true
  rescue Fbe::Error
    false
  end
end
