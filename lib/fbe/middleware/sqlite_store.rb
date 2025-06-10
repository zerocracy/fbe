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

  def initialize(path, version)
    raise ArgumentError, 'Database path cannot be nil or empty' if path.nil? || path.empty?
    dir = File.dirname(path)
    raise ArgumentError, "Directory #{dir} does not exist" unless File.directory?(dir)
    raise ArgumentError, 'Version cannot be nil or empty' if version.nil? || version.empty?
    @path = File.absolute_path(path)
    @version = version
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
    return if value.is_a?(Array) && value.any? do |vv|
      req = JSON.parse(vv[0])
      req['url'].include?('?') || req['method'] != 'get'
    end
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
    perform do |t|
      t.execute 'DELETE FROM cache;'
      t.execute "UPDATE meta SET value = ? WHERE key = 'version';", [@version]
    end
    @db.execute 'VACUUM;'
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
          t.execute 'CREATE INDEX IF NOT EXISTS cache_key_idx ON cache(key);'
          t.execute 'CREATE TABLE IF NOT EXISTS meta(key TEXT UNIQUE NOT NULL, value TEXT);'
          t.execute 'CREATE INDEX IF NOT EXISTS meta_key_idx ON meta(key);'
          t.execute "INSERT INTO meta(key, value) VALUES('version', ?) ON CONFLICT(key) DO NOTHING;", [@version]
        end
        if d.execute("SELECT value FROM meta WHERE key = 'version' LIMIT 1;").dig(0, 0) != @version
          d.transaction do |t|
            t.execute 'DELETE FROM cache;'
            t.execute "UPDATE meta SET value = ? WHERE key = 'version';", [@version]
          end
          d.execute 'VACUUM;'
        end
        at_exit { @db&.close }
      end
    @db.transaction(&)
  end
end
