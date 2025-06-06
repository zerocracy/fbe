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
  attr_reader :store

  def self.store
    @store ||=
      begin
        path = File.expand_path('../../../.test.db1', __dir__)
        Fbe::Middleware::SqliteStore.new(path)
      end
  end

  def setup
    @store = self.class.store
    store.clear
  end

  def test_sqlite_store
    assert_nil(store.read('my_key'))
    assert_nil(store.delete('my_key'))
    assert_nil(store.write('my_key', 'some value'))
    assert_equal('some value', store.read('my_key'))
    assert_nil(store.write('my_key', 'some value 2'))
    assert_equal('some value 2', store.read('my_key'))
    assert_nil(store.delete('my_key'))
    assert_nil(store.read('my_key'))
  end

  def test_sqlite_store_empty_all
    assert_empty(store.all)
  end
end
