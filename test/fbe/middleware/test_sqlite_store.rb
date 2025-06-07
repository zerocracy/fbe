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
  def test_read_write_delete
    with_tmpfile do |path|
      store = Fbe::Middleware::SqliteStore.new(path)
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

  def test_read_with_wrong_path
    assert_raises(ArgumentError) do
      Fbe::Middleware::SqliteStore.new(nil).read('my_key')
    end
    assert_raises(ArgumentError) do
      Fbe::Middleware::SqliteStore.new('').read('my_key')
    end
    assert_raises(ArgumentError) do
      Fbe::Middleware::SqliteStore.new('/fakepath/fakefolder/test.db').read('my_key')
    end
  end

  def test_empty_all_if_not_written
    with_tmpfile do |path|
      store = Fbe::Middleware::SqliteStore.new(path)
      assert_empty(store.all)
    end
  end

  def test_setup
    with_tmpfile do |path|
      store = Fbe::Middleware::SqliteStore.new(path)
      refute_predicate store, :setup?
      2.times { store.setup }
      assert_predicate store, :setup?
      store.drop
      refute_predicate store, :setup?
      2.times { store.setup }
      assert_predicate store, :setup?
    end
  end

  def test_close
    with_tmpfile do |path|
      store = Fbe::Middleware::SqliteStore.new(path)
      store.write('my_key', 'my_value')
      2.times { store.close }
      assert_equal('my_value', store.read('my_key'))
    end
  end

  def test_clear
    with_tmpfile do |path|
      store = Fbe::Middleware::SqliteStore.new(path)
      store.write('my_key', 'my_value')
      assert_equal('my_value', store.read('my_key'))
      store.clear
      assert_nil(store.read('my_key'))
    end
  end

  private

  def with_tmpfile(name = 'test.db', &)
    Dir.mktmpdir do |dir|
      yield File.expand_path(name, dir)
    end
  end
end
