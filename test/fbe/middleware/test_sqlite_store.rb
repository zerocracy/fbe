# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'securerandom'
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
      store = Fbe::Middleware::SqliteStore.new(f, '0.0.0')
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
      store = Fbe::Middleware::SqliteStore.new(f, '0.0.0', loog: fake_loog)
      assert_empty(store.all)
    end
  end

  def test_clear_all_keys
    with_tmpfile('a.db') do |f|
      store = Fbe::Middleware::SqliteStore.new(f, '0.0.0', loog: fake_loog)
      k = 'a key'
      store.write(k, 'some value')
      store.clear
      assert_empty(store.all)
    end
  end

  def test_empty_all_if_not_written
    with_tmpfile do |f|
      store = Fbe::Middleware::SqliteStore.new(f, '0.0.0', loog: fake_loog)
      assert_empty(store.all)
    end
  end

  def test_wrong_db_path
    assert_raises(ArgumentError) do
      Fbe::Middleware::SqliteStore.new(nil, '0.0.0', loog: fake_loog).read('my_key')
    end
    assert_raises(ArgumentError) do
      Fbe::Middleware::SqliteStore.new('', '0.0.0', loog: fake_loog).read('my_key')
    end
    assert_raises(ArgumentError) do
      Fbe::Middleware::SqliteStore.new('/fakepath/fakefolder/test.db', '0.0.0', loog: fake_loog).read('my_key')
    end
  end

  def test_not_db_file
    with_tmpfile do |f|
      File.binwrite(f, Array.new(20) { rand(0..255) }.pack('C*'))
      ex =
        assert_raises(SQLite3::NotADatabaseException) do
          Fbe::Middleware::SqliteStore.new(f, '0.0.0', loog: fake_loog).read('my_key')
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
        Fbe::Middleware::SqliteStore.new(f.path, '0.0.0').then do |s|
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

  def test_different_versions
    with_tmpfile('d.db') do |f|
      Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog).then do |store|
        store.write('kkk1', 'some value')
        store.write('kkk2', 'another value')
      end
      Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog).then do |store|
        assert_equal('some value', store.read('kkk1'))
        assert_equal('another value', store.read('kkk2'))
      end
      Fbe::Middleware::SqliteStore.new(f, '0.0.2', loog: fake_loog).then do |store|
        assert_nil(store.read('kkk1'))
        assert_nil(store.read('kkk2'))
      end
    end
  end

  def test_initialize_wrong_version
    with_tmpfile('e.db') do |f|
      msg = 'Version cannot be nil or empty'
      assert_raises(ArgumentError) { Fbe::Middleware::SqliteStore.new(f, nil, loog: fake_loog) }.then do |ex|
        assert_match(msg, ex.message)
      end
      assert_raises(ArgumentError) { Fbe::Middleware::SqliteStore.new(f, '', loog: fake_loog) }.then do |ex|
        assert_match(msg, ex.message)
      end
    end
  end

  def test_skip_write_if_value_more_then_10k_bytes
    with_tmpfile('a.db') do |f|
      Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog).then do |store|
        store.write('a', 'a' * 9_997)
        store.write('b', 'b' * 9_998)
        store.write('c', SecureRandom.alphanumeric((19_999 * 1.4).to_i))
        store.write('d', SecureRandom.alphanumeric((30_000 * 1.4).to_i))
        assert_equal('a' * 9_997, store.read('a'))
        assert_equal('b' * 9_998, store.read('b'))
        assert_nil(store.read('c'))
        assert_nil(store.read('d'))
      end
    end
  end

  def test_shrink_cache_if_more_then_10_mb
    with_tmpfile('large.db') do |f|
      Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog).then do |store|
        key = 'aaa'
        store.write('a', 'aa')
        Time.stub(:now, (Time.now - (5 * 60 * 60)).round) do
          store.write('b', 'bb')
          store.write('c', 'cc')
        end
        assert_equal('cc', store.read('c'))
        Time.stub(:now, rand((Time.now - (5 * 60 * 60))..Time.now).round) do
          value = SecureRandom.alphanumeric(2048)
          10_240.times do
            store.write(key, value)
            key = key.next
          end
        end
      end
      assert_operator(File.size(f), :>, 10 * 1024 * 1024)
      Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog).then do |store|
        assert_equal('aa', store.read('a'))
        assert_nil(store.read('b'))
        assert_equal('cc', store.read('c'))
        assert_operator(File.size(f), :<=, 10 * 1024 * 1024)
      end
    end
  end

  def test_upgrade_sqlite_schema_for_add_touched_at_column
    with_tmpfile('a.db') do |f|
      SQLite3::Database.new(f).tap do |d|
        d.execute 'CREATE TABLE IF NOT EXISTS cache(key TEXT UNIQUE NOT NULL, value TEXT);'
        [
          ['key1', Zlib::Deflate.deflate(JSON.dump('value1'))],
          ['key2', Zlib::Deflate.deflate(JSON.dump('value2'))]
        ].each { d.execute 'INSERT INTO cache(key, value) VALUES(?1, ?2);', _1 }
        d.execute 'CREATE TABLE IF NOT EXISTS meta(key TEXT UNIQUE NOT NULL, value TEXT);'
        d.execute "INSERT INTO meta(key, value) VALUES('version', ?);", ['0.0.1']
      end
      Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog).then do |store|
        assert_equal('value1', store.read('key1'))
        assert_equal('value2', store.read('key2'))
      rescue SQLite3::SQLException => e
        assert_nil(e)
      end
    end
  end

  def test_use_compress_for_stored_data
    with_tmpfile('c.db') do |f|
      Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog).then do |store|
        a = SecureRandom.alphanumeric(200)
        store.write('a', a)
        store.write('b', 'b' * 100_000)
        assert_equal(a, store.read('a'))
        assert_equal('b' * 100_000, store.read('b'))
        store.all.each do |k, v|
          case k
          when 'a'
            assert_operator(v.size, :<, a.size)
          when 'b'
            assert_operator(v.size, :<, 100_000)
          end
        end
      end
    end
  end

  def test_corrupted_compression_stored_data
    with_tmpfile('c.db') do |f|
      SQLite3::Database.new(f).tap do |d|
        d.execute 'CREATE TABLE IF NOT EXISTS cache(key TEXT UNIQUE NOT NULL, value TEXT);'
        [
          ['my_key', JSON.dump('value1')]
        ].each { d.execute 'INSERT INTO cache(key, value) VALUES(?1, ?2);', _1 }
        d.execute 'CREATE TABLE IF NOT EXISTS meta(key TEXT UNIQUE NOT NULL, value TEXT);'
        d.execute "INSERT INTO meta(key, value) VALUES('version', ?);", ['0.0.1']
      end
      loog = Loog::Buffer.new
      Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog:).then do |store|
        assert_nil(store.read('my_key'))
        assert_match(
          'Failed to decompress cached value for key: my_key, error: incorrect header check',
          loog.to_s
        )
      end
    end
  end

  private

  def with_tmpfile(name = 'test.db', &)
    Dir.mktmpdir do |dir|
      yield File.expand_path(name, dir)
    end
  end
end
