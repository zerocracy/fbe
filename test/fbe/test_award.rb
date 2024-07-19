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
require_relative '../test__helper'
require_relative '../../lib/fbe/award'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestAward < Minitest::Test
  def test_simple
    a = Fbe::Award.new(
      '
      (award
        (explain "When a bug is resolved by the person who was assigned to it, a reward is granted to this person")
        (in hours "hours passed between bug reported and closed")
        (let max 36)
        (let basis 30)
        (give basis "as a basis")
        (let fee 10)
        (aka
          (set b1 (if (lt hours max) fee 0))
          (give b1 "for resolving the bug in ${hours} (<${max}) hours")
          "add ${+fee} if it was resolved in less than ${max} hours")
        (set days (div hours 24))
        (set b2 (times days -1))
        (let worst -20)
        (set b2 (max b2 worst))
        (let at_least -5)
        (set b2 (if (lt b2 at_least) b2 0))
        (set b2 (between b2 3 120))
        (give b2 "for holding the bug open for too long (${days} days)"))
      '
    )
    b = a.bill(hours: 10)
    assert(b.points <= 100)
    assert(b.points >= 5)
    assert_equal(43, b.points)
    g = b.greeting
    [
      'You\'ve earned +43 points for this',
      '+10 for resolving the bug in 10',
      'too long (0 days)',
      'bug in 10 (<36) hours',
      '+30 as a basis'
    ].each { |t| assert(g.include?(t), g) }
    md = a.policy.markdown
    [
      'First, assume that _hours_ is hours',
      ', and award _b₂_'
    ].each { |t| assert(md.include?(t), md) }
  end

  def test_some_terms
    {
      '(let x 25)' => 0,
      '(award (give 25 "for being a good boy"))' => 25,
      '(award (give (between 42 -10 -50) "empty"))' => -10,
      '(award (give (between -3 -10 -50) "empty"))' => -10,
      '(award (give (between -100 -50 -10) "empty"))' => -50
    }.each do |q, v|
      a = Fbe::Award.new(q)
      assert_equal(v, a.bill.points, q)
    end
  end

  def test_some_policies
    {
      '(award (let x_a 25) (set z (plus x_a 1)) (give z "..."))' =>
        'First, let _x-a_ be equal to **25**. Then, set _z_ to _x-a_ + **1**, and award _z_.',
      '(award (aka (let x 17) (give x "hey") "add ${x} when necessary"))' =>
        'Just add **17** when necessary'
    }.each do |q, t|
      md = Fbe::Award.new(q).policy.markdown
      assert(md.include?(t), md)
    end
  end
end
