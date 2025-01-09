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
require 'loog'
require_relative '../test__helper'
require_relative '../../lib/fbe/enter'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class TestEnter < Minitest::Test
  def test_simple
    WebMock.disable_net_connect!
    options = Judges::Options.new({ 'zerocracy_token' => '00000-0000-0000-00000' })
    stub_request(:get, 'https://api.zerocracy.com/valves/result?badge=foo')
      .to_return(status: 204)
    stub_request(:post, 'https://api.zerocracy.com/valves/add?badge=foo&job=0&result=hi&why=no%20reason')
      .to_return(status: 302)
    assert_equal('hi', Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 'hi' })
  end

  def test_in_testing_mode
    WebMock.enable_net_connect!
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('hi', Fbe.enter('foo', 'no reason', options:, loog: Loog::NULL) { 'hi' })
  end
end
