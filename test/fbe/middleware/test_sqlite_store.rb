# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'qbash'
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

  def test_clear_all_keys
    with_tmpfile('a.db') do |f|
      store = Fbe::Middleware::SqliteStore.new(f)
      k = 'a key'
      store.write(k, 'some value')
      store.clear
      assert_empty(store.all)
    end
  end

  def test_empty_all_if_not_written
    with_tmpfile do |f|
      store = Fbe::Middleware::SqliteStore.new(f)
      assert_empty(store.all)
    end
  end

  def test_wrong_db_path
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

  def test_not_db_file
    with_tmpfile do |f|
      File.binwrite(f, Array.new(20) { rand(0..255) }.pack('C*'))
      ex =
        assert_raises(SQLite3::NotADatabaseException) do
          Fbe::Middleware::SqliteStore.new(f).read('my_key')
        end
      assert_match('file is not a database', ex.message)
    end
  end

  def test_defer_db_close_callback
    txt = <<~RUBY
      require 'tempfile'
      require 'sqlite3'
      require 'fbe/middleware/sqlite_store'

      SQLite3::Database.class_eval do
        prepend(Module.new do
          def close
            super
            puts 'closed sqlite after process exit'
          end
        end)
      end

      Tempfile.open('test.db') do |f|
        Fbe::Middleware::SqliteStore.new(f.path).then do |s|
          s.write('my_key', 'my_value')
          s.read('my_key')
        end
      end
    RUBY
    out =
      qbash(
        'bundle exec ruby ' \
        "-I#{Shellwords.escape(File.expand_path('../../../lib', __dir__))} " \
        "-e #{Shellwords.escape(txt)} 2>&1"
      )
    assert_match('closed sqlite after process exit', out)
  end

  private

  def with_tmpfile(name = 'test.db', &)
    Dir.mktmpdir do |dir|
      yield File.expand_path(name, dir)
    end
  end
end
