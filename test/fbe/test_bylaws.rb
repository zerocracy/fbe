# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
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
    assert(laws.size > 1)
    assert(!laws[:published_release_was_rewarded].nil?)
  end

  def test_check_all_bills
    awards = {
      published_release_was_rewarded: {
        { hoc: 0, contributors: 1 } => 24,
        { hoc: 10, contributors: 1 } => 24,
        { hoc: 100, contributors: 1 } => 24,
        { hoc: 500, contributors: 1 } => 29,
        { hoc: 1_000, contributors: 1 } => 32,
        { hoc: 10_000, contributors: 1 } => 32,
        { hoc: 30_000, contributors: 1 } => 32
      },
      resolved_bug_was_rewarded: {
        { hours: 1, self: 0 } => 24,
        { hours: 48, self: 0 } => 14,
        { hours: 80, self: 0 } => 13,
        { hours: 300, self: 0 } => 4,
        { hours: 3_000, self: 0 } => 4,
        { hours: 30_000, self: 0 } => 4,
        { hours: 1, self: 1 } => 10
      },
      push_to_master_was_punished: {
        {} => -16
      },
      code_review_was_rewarded: {
        { hoc: 0, comments: 0, self: 0 } => 4,
        { hoc: 3, comments: 0, self: 0 } => 4,
        { hoc: 78, comments: 7, self: 0 } => 8,
        { hoc: 600, comments: 1, self: 0 } => 10,
        { hoc: 500, comments: 40, self: 0 } => 26,
        { hoc: 5_000, comments: 100, self: 0 } => 32,
        { hoc: 100, comments: 50, self: 1 } => 4,
        { hoc: 10_000, comments: 200, self: 1 } => 4
      },
      code_contribution_was_rewarded: {
        { hoc: 0, comments: 0, reviews: 0 } => 4,
        { hoc: 3, comments: 0, reviews: 0 } => 4,
        { hoc: 78, comments: 0, reviews: 0 } => 4,
        { hoc: 78, comments: 1, reviews: 0 } => 4,
        { hoc: 50, comments: 15, reviews: 0 } => 4,
        { hoc: 50, comments: 25, reviews: 0 } => 4,
        { hoc: 180, comments: 7, reviews: 2 } => 17,
        { hoc: 150, comments: 5, reviews: 1 } => 16,
        { hoc: 500, comments: 25, reviews: 2 } => 4,
        { hoc: 99, comments: 6, reviews: 1 } => 8,
        { hoc: 1_500, comments: 3, reviews: 0 } => 4,
        { hoc: 15_000, comments: 40, reviews: 0 } => 4
      },
      dud_was_punished: {
        {} => -16
      },
      bug_report_was_rewarded: {
        {} => 16
      },
      enhancement_suggestion_was_rewarded: {
        {} => 16
      },
      bad_branch_name_was_punished: {
        {} => -12
      }
    }
    awards.each do |title, pairs|
      a = Fbe::Award.new(Fbe.bylaws[title])
      help = [
        "  #{title}: {\n    ",
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
