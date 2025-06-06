# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../test__helper'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/sqlite_store'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class SqliteStoreTest < Fbe::Test
  def test_sqlite_store
    Dir.mktmpdir do |dir|
      store = Fbe::Middleware::SqliteStore.new(File.expand_path('test.db', dir))
      assert_nil(store.read('my_key'))
      assert_nil(store.delete('my_key'))
      assert_nil(store.write('my_key', 'some value'))
      assert_equal('some value', store.read('my_key'))
      assert_nil(store.write('my_key', 'some value 2'))
      assert_equal('some value 2', store.read('my_key'))
      assert_nil(store.delete('my_key'))
      assert_nil(store.read('my_key'))
    end
  end

  def test_sqlite_store_empty_all
    Dir.mktmpdir do |dir|
      store = Fbe::Middleware::SqliteStore.new(File.expand_path('test.db', dir))
      assert_empty(store.all)
    end
  end
end
