# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/consider'
require_relative '../../lib/fbe/fb'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestConsider < Fbe::Test
  def test_with_simple_query
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '3' } }
    )
    $fb = Factbase.new
    $fb.insert.foo = 42
    $epoch = Time.now
    $global = {}
    $options = Judges::Options.new
    $loog = Loog::NULL
    $judge = ''
    Fbe.consider('(always)') do |f|
      f.bar = 7
    end
    assert_equal(1, $fb.size)
  end
end
