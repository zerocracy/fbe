# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../lib/fbe'
require_relative 'test__helper'

# Main module test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestFbe < Fbe::Test
  def test_simple
    refute_nil(Fbe::VERSION)
  end

  def test_error_is_not_a_runtime_error
    assert_kind_of(StandardError, Fbe::Error.new)
    refute_kind_of(RuntimeError, Fbe::Error.new)
  end

  def test_documented_raise_tags_name_the_class_that_is_raised
    Dir[File.join(__dir__, '../lib/**/*.rb')].each do |f|
      tags = File.readlines(f).grep(/@raise \[/)
      tags.each do |t|
        refute_includes(t, '[RuntimeError]', "#{f} promises RuntimeError, but Fbe raises Fbe::Error")
      end
    end
  end
end
