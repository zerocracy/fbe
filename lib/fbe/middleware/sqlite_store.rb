# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require 'sqlite3'
require_relative '../../fbe'
require_relative '../../fbe/middleware'

# Persisted SQLite store for Faraday::HttpCache
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Middleware::SqliteStore
  def initialize(path)
    raise ArgumentError, 'Database path cannot be nil or empty' if path.nil? || path.empty?
    dir = File.dirname(path)
    raise ArgumentError, "Directory #{dir} does not exist" unless File.directory?(dir)
    @path = path
    open
    prepare
    at_exit { close }
  end

  def read(key)
    value = perform { _1.execute('SELECT value FROM cache WHERE key = ? LIMIT 1', [key]) }.dig(0, 0)
    JSON.parse(value) if value
  end

  def delete(key)
    perform { _1.execute('DELETE FROM cache WHERE key = ?', [key]) }
    nil
  end

  def write(key, value)
    value = JSON.dump(value)
    perform do |tdb|
      tdb.execute(<<~SQL, [key, value])
        INSERT INTO cache(key, value) VALUES(?1, ?2)
        ON CONFLICT(key) DO UPDATE SET value = ?2
      SQL
    end
    nil
  end

  def open
    return if @db
    @db = SQLite3::Database.new(@path)
  end

  def prepare
    perform do |tdb|
      tdb.execute 'CREATE TABLE IF NOT EXISTS cache(key TEXT UNIQUE NOT NULL, value TEXT);'
      tdb.execute 'CREATE INDEX IF NOT EXISTS key_idx ON cache(key);'
    end
  end

  def close
    return if !@db || @db.closed?
    @db.close
    @db = nil
  end

  def clear
    perform { _1.execute 'DELETE FROM cache;' }
  end

  def drop
    perform { _1.execute 'DROP TABLE IF EXISTS cache;' }
  end

  def all
    perform { _1.execute('SELECT key, value FROM cache') }
  end

  private

  def perform(&)
    @db.transaction(&)
  end
end
