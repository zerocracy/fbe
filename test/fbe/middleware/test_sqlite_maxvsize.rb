# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/sqlite_store'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class SqliteMaxvsizeTest < Fbe::Test
  def test_skips_a_value_larger_than_the_limit
    Dir.mktmpdir do |dir|
      store = Fbe::Middleware::SqliteStore.new(
        File.expand_path('m.db', dir), '0.0.0', loog: fake_loog, maxvsize: '10Kb'
      )
      store.write('k', 'x' * 100_000)
      assert_nil(store.read('k'))
    end
  end
end
