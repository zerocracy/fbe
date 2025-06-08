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
    with_tmpfile('x.db') do |f|
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
      assert_path_exists(f)
    end
  end

  def test_returns_empty_list
    with_tmpfile('b.db') do |f|
      store = Fbe::Middleware::SqliteStore.new(f)
      assert_empty(store.all)
    end
  end

  def test_drops_all_keys
    with_tmpfile('a.db') do |f|
      store = Fbe::Middleware::SqliteStore.new(f)
      k = 'a key'
      store.write(k, 'some value')
      store.drop
      store.prepare
      assert_empty(store.all)
    end
  end

  def test_read_from_wrong_db_path
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
    with_tmpfile do |f|
      store = Fbe::Middleware::SqliteStore.new(f)
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
