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
  def test_simple_caching_algorithm
    Dir.mktmpdir do |dir|
      f = File.expand_path('x.db', dir)
      store = Fbe::Middleware::SqliteStore.new(f)
      k = 'some-key'
      assert_nil(store.read(k))
      assert_nil(store.delete(k))
      v1 = 'first value to save'
      assert_nil(store.write(k, v1))
      assert_equal(v1, store.read(k))
      v2 = 'another value to save'
      assert_nil(store.write(k, v2))
      assert_equal(v2, store.read(k))
      assert_nil(store.delete(k))
      assert_nil(store.read(k))
      store.close
      assert_path_exists(f)
    end
  end

  def test_returns_empty_list
    Dir.mktmpdir do |dir|
      store = Fbe::Middleware::SqliteStore.new(File.expand_path('b.db', dir))
      assert_empty(store.all)
      store.close
    end
  end

  def test_drops_all_keys
    Dir.mktmpdir do |dir|
      store = Fbe::Middleware::SqliteStore.new(File.expand_path('a.db', dir))
      k = 'a key'
      store.write(k, 'some value')
      store.drop
      store.prepare
      assert_empty(store.all)
      store.close
    end
  end
end
