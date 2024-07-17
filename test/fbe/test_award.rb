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
        (explain "When a bug is resolved by the person who was assigned to it, a reward is granted to this person.")
        (in hours "hours passed between bug reported and closed")
        (let max 36)
        (let basis 30)
        (give basis "as a basis")
        (set b1 (if (lt hours max) 10 0))
        (give b1 "for resolving the bug in ${hours} (<${max}) hours")
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
    assert(g.include?('You\'ve earned +43 points for this'), g)
    assert(g.include?('+10 for resolving the bug in 10'), g)
    md = a.policy.markdown
    assert(md.include?('First, assume that _hours_ is hours'), md)
  end

  def test_very_short
    a = Fbe::Award.new('(award (give 25 "for being a good boy"))')
    assert_equal(25, a.bill.points)
  end

  def test_broken
    a = Fbe::Award.new('(let x 25)')
    assert_equal(0, a.bill.points)
  end
end
