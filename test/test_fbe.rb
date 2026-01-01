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
end
