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
  attr_reader :path

  def initialize(path)
    raise ArgumentError, 'Database path cannot be nil or empty' if path.nil? || path.empty?
    dir = File.dirname(path)
    raise ArgumentError, "Directory #{dir} does not exist" unless File.directory?(dir)
    @path = File.absolute_path(path)
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
    perform do |t|
      t.execute(<<~SQL, [key, value])
        INSERT INTO cache(key, value) VALUES(?1, ?2)
        ON CONFLICT(key) DO UPDATE SET value = ?2
      SQL
    end
    nil
  end

  def clear
    perform { _1.execute 'DELETE FROM cache;' }
  end

  def all
    perform { _1.execute('SELECT key, value FROM cache') }
  end

  private

  def perform(&)
    @db ||=
      SQLite3::Database.new(@path).tap do |d|
        d.transaction do |t|
          t.execute 'CREATE TABLE IF NOT EXISTS cache(key TEXT UNIQUE NOT NULL, value TEXT);'
          t.execute 'CREATE INDEX IF NOT EXISTS key_idx ON cache(key);'
        end
        at_exit { @db.close if @db && !@db.closed? }
      end
    @db.transaction(&)
  end
end
