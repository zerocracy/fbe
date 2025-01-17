# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024-2025 Zerocracy
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
require 'factbase'
require 'loog'
require 'judges/options'
require_relative '../test__helper'
require_relative '../../lib/fbe'
require_relative '../../lib/fbe/fb'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestFb < Minitest::Test
  def test_simple
    $fb = Factbase.new
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::Buffer.new
    Fbe.fb.insert.foo = 1
    Fbe.fb.insert.bar = 2
    assert_equal(1, Fbe.fb.query('(exists bar)').each.to_a.size)
    stdout = $loog.to_s
    assert(stdout.include?('Inserted new fact #1'), stdout)
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
    f = Fbe.fb.query('(always)').each.to_a.first
    assert(!f._id.nil?)
    assert(!f._time.nil?)
    assert(!f._version.nil?)
    assert(!f._job.nil?)
  end
end
