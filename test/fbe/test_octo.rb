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
require 'judges/options'
require 'loog'
require_relative '../test__helper'
require_relative '../../lib/fbe/octo'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Zerocracy
# License:: MIT
class TestOcto < Minitest::Test
  def test_simple_use
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    o = Fbe.octo(loog: Loog::NULL, global:, options:)
    assert(!o.off_quota)
    assert(!o.pull_request('foo/foo', 42).nil?)
    assert(!o.commit_pulls('foo/foo', 'sha').nil?)
  end

  def test_post_comment
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    o = Fbe.octo(loog: Loog::NULL, global:, options:)
    assert_equal(42, o.add_comment('foo/foo', 4, 'hello!')[:id])
  end

  def test_rate_limit
    o = Fbe::FakeOctokit.new
    assert_equal(100, o.rate_limit.remaining)
  end

  def test_with_broken_token
    skip # it's a "live" test, run it manually if you need it
    global = {}
    options = Judges::Options.new({ 'github_token' => 'incorrect-value' })
    o = Fbe.octo(loog: Loog::NULL, global:, options:)
    assert_raises { o.repository('zerocracy/fbe') }
  end

  def test_commit_pulls
    skip # it's a "live" test, run it manually if you need it
    o = Fbe.octo(loog: Loog::NULL, global: {}, options: Judges::Options.new)
    assert_equal(1, o.commit_pulls('zerocracy/fbe', '0b7d0699bd744b62c0731064c2adaad0c58e1416').size)
    assert_equal(0, o.commit_pulls('zerocracy/fbe', '16b3ea6b71c6e932ba7666c40ca846ecaa6d6f0d').size)
  end
end
