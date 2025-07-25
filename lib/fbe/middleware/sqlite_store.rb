# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'filesize'
require 'json'
require 'loog'
require 'sqlite3'
require 'time'
require 'zlib'
require_relative '../../fbe'
require_relative '../../fbe/middleware'

# Persisted SQLite store for Faraday::HttpCache
#
# This class provides a persistent cache store backed by SQLite for use with
# Faraday::HttpCache middleware. It's designed to cache HTTP responses from
# GitHub API calls to reduce API rate limit consumption and improve performance.
#
# Key features:
# - Automatic version management to invalidate cache on version changes
# - Size-based cache eviction (configurable, defaults to 10MB)
# - Thread-safe SQLite transactions
# - JSON serialization for cached values
# - Filtering of non-cacheable requests (non-GET, URLs with query parameters)
#
# Usage example:
#   store = Fbe::Middleware::SqliteStore.new(
#     '/path/to/cache.db',
#     '1.0.0',
#     loog: logger,
#     maxsize: '50Mb'
#   )
#   # Use with Faraday
#   Faraday.new do |builder|
#     builder.use Faraday::HttpCache, store: store
#   end
#
# The store automatically manages the SQLite database schema and handles
# cleanup operations when the database grows too large. Old entries are
# deleted based on their last access time to maintain the configured size limit.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Middleware::SqliteStore
  attr_reader :path

  # Initialize the SQLite store.
  # @param path [String] Path to the SQLite database file
  # @param version [String] Version identifier for cache compatibility
  # @param loog [Loog] Logger instance (optional, defaults to Loog::NULL)
  # @param maxsize [Integer] Maximum database size in bytes (optional, defaults to 10MB)
  # @param maxvsize [Integer] Maximum size in bytes of a single value (optional, defaults to 10Kb)
  # @param ttl [Integer, nil] lifetime of keys in hours
  # @param cache_min_age [Integer, nil] age which will could be overwritten in cache-control header
  # @raise [ArgumentError] If path is nil/empty, directory doesn't exist, version is nil/empty,
  # or ttl is not nil or not Integer or not positive
  def initialize(path, version, loog: Loog::NULL, maxsize: '10Mb', maxvsize: '10Kb', ttl: nil, cache_min_age: nil)
    raise ArgumentError, 'Database path cannot be nil or empty' if path.nil? || path.empty?
    dir = File.dirname(path)
    raise ArgumentError, "Directory #{dir} does not exist" unless File.directory?(dir)
    raise ArgumentError, 'Version cannot be nil or empty' if version.nil? || version.empty?
    @path = File.absolute_path(path)
    @version = version
    @loog = loog
    @maxsize = Filesize.from(maxsize.to_s).to_i
    @maxvsize = Filesize.from(maxvsize.to_s).to_i
    raise ArgumentError, 'TTL can be nil or Integer > 0' if !ttl.nil? && !(ttl.is_a?(Integer) && ttl.positive?)
    @ttl = ttl
    if !cache_min_age.nil? && !(cache_min_age.is_a?(Integer) && cache_min_age.positive?)
      raise ArgumentError, 'Cache min age can be nil or Integer > 0'
    end
    @cache_min_age = cache_min_age
  end

  # Read a value from the cache.
  # @param key [String] The cache key to read
  # @return [Object, nil] The cached value parsed from JSON, or nil if not found
  def read(key)
    value = perform do |t|
      t.execute('UPDATE cache SET touched_at = ?2 WHERE key = ?1;', [key, Time.now.utc.iso8601])
      t.execute('SELECT value FROM cache WHERE key = ? LIMIT 1;', [key])
    end.dig(0, 0)
    return unless value
    begin
      JSON.parse(Zlib::Inflate.inflate(value))
    rescue Zlib::Error => e
      @loog.info("Failed to decompress cached value for key: #{key}, error: #{e.message}, the key will be deleted")
      delete(key)
    end
  end

  # Delete a key from the cache.
  # @param key [String] The cache key to delete
  # @return [nil]
  def delete(key)
    perform { _1.execute('DELETE FROM cache WHERE key = ?', [key]) }
    nil
  end

  # Write a value to the cache.
  # @param key [String] The cache key to write
  # @param value [Object] The value to cache (will be JSON encoded)
  # @return [nil]
  # @note Values larger than 10KB are not cached
  # @note Non-GET requests and URLs with query parameters are not cached
  def write(key, value)
    return if value.is_a?(Array) && value.any? do |vv|
      req = JSON.parse(vv[0])
      req['method'] != 'get'
    end
    if @cache_min_age && value.is_a?(Array) && value[0].is_a?(Array) && value[0].size > 1
      begin
        resp = JSON.parse(value[0][1])
      rescue TypeError, JSON::ParserError => e
        @loog.info("Failed to parse response to rewrite the cache age: #{e.message}")
        resp = nil
      end
      cache_control = resp.dig('response_headers', 'cache-control') if resp.is_a?(Hash)
      if cache_control && !cache_control.empty?
        %w[max-age s-maxage].each do |key|
          age = cache_control.scan(/#{key}=(\d+)/i).first&.first&.to_i
          if age
            age = [age, @cache_min_age].max
            cache_control = cache_control.sub(/#{key}=(\d+)/, "#{key}=#{age}")
          end
        end
        resp['response_headers']['cache-control'] = cache_control
        value[0][1] = JSON.dump(resp)
      end
    end
    value = Zlib::Deflate.deflate(JSON.dump(value))
    return if value.bytesize > @maxvsize
    perform do |t|
      t.execute(<<~SQL, [key, value, Time.now.utc.iso8601])
        INSERT INTO cache(key, value, touched_at, created_at) VALUES(?1, ?2, ?3, ?3)
        ON CONFLICT(key) DO UPDATE SET value = ?2, touched_at = ?3, created_at = ?3
      SQL
    end
    nil
  end

  # Clear all entries from the cache.
  # @return [void]
  def clear
    perform do |t|
      t.execute 'DELETE FROM cache;'
      t.execute "UPDATE meta SET value = ? WHERE key = 'version';", [@version]
    end
    @db.execute 'VACUUM;'
  end

  # Get all entries from the cache.
  # @return [Array<Array>] Array of [key, value] pairs
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
        if d.execute("SELECT 1 FROM pragma_table_info('cache') WHERE name = 'touched_at';").dig(0, 0) != 1
          d.transaction do |t|
            t.execute 'ALTER TABLE cache ADD COLUMN touched_at TEXT;'
            t.execute 'UPDATE cache set touched_at = ?;', [Time.now.utc.iso8601]
            t.execute 'ALTER TABLE cache RENAME TO cache_old;'
            t.execute <<~SQL
              CREATE TABLE IF NOT EXISTS cache(
                key TEXT UNIQUE NOT NULL, value TEXT, touched_at TEXT NOT NULL
              );
            SQL
            t.execute 'INSERT INTO cache SELECT * FROM cache_old;'
            t.execute 'DROP TABLE cache_old;'
            t.execute 'CREATE INDEX IF NOT EXISTS cache_key_idx ON cache(key);'
            t.execute 'CREATE INDEX IF NOT EXISTS cache_touched_at_idx ON cache(touched_at);'
          end
          d.execute 'VACUUM;'
        end
        if d.execute("SELECT 1 FROM pragma_table_info('cache') WHERE name = 'created_at';").dig(0, 0) != 1
          d.transaction do |t|
            t.execute 'ALTER TABLE cache ADD COLUMN created_at TEXT;'
            t.execute 'UPDATE cache set created_at = ?;', [Time.now.utc.iso8601]
            t.execute 'ALTER TABLE cache RENAME TO cache_old;'
            t.execute <<~SQL
              CREATE TABLE IF NOT EXISTS cache(
                key TEXT UNIQUE NOT NULL, value TEXT, touched_at TEXT NOT NULL, created_at TEXT NOT NULL
              );
            SQL
            t.execute 'INSERT INTO cache SELECT * FROM cache_old;'
            t.execute 'DROP TABLE cache_old;'
            t.execute 'CREATE INDEX IF NOT EXISTS cache_key_idx ON cache(key);'
            t.execute 'CREATE INDEX IF NOT EXISTS cache_touched_at_idx ON cache(touched_at);'
            t.execute 'CREATE INDEX IF NOT EXISTS cache_created_at_idx ON cache(created_at);'
          end
          d.execute 'VACUUM;'
        end
        found = d.execute("SELECT value FROM meta WHERE key = 'version' LIMIT 1;").dig(0, 0)
        if found != @version
          @loog.info("Version mismatch in SQLite cache: stored '#{found}' != current '#{@version}', cleaning up")
          d.transaction do |t|
            t.execute 'DELETE FROM cache;'
            t.execute "UPDATE meta SET value = ? WHERE key = 'version';", [@version]
          end
          d.execute 'VACUUM;'
        end
        unless @ttl.nil?
          d.transaction do |t|
            t.execute <<~SQL, [(Time.now.utc - (@ttl * 60 * 60)).iso8601]
              DELETE FROM cache
              WHERE key IN (SELECT key FROM cache WHERE (created_at < ?));
            SQL
          end
          d.execute 'VACUUM;'
        end
        if File.size(@path) > @maxsize
          @loog.info(
            "SQLite cache file size (#{Filesize.from(File.size(@path).to_s).pretty} bytes) exceeds " \
            "#{Filesize.from(@maxsize.to_s).pretty}, cleaning up old entries"
          )
          deleted = 0
          while d.execute(<<~SQL).dig(0, 0) > @maxsize
            SELECT (page_count - freelist_count) * page_size AS size
            FROM pragma_page_count(), pragma_freelist_count(), pragma_page_size();
          SQL
            d.transaction do |t|
              t.execute <<~SQL
                DELETE FROM cache
                WHERE key IN (SELECT key FROM cache ORDER BY touched_at LIMIT 50)
              SQL
              deleted += t.changes
            end
          end
          d.execute 'VACUUM;'
          @loog.info(
            "Deleted #{deleted} old cache entries, " \
            "new file size: #{Filesize.from(File.size(@path).to_s).pretty} bytes"
          )
        end
        at_exit { @db&.close }
      end
    @db.transaction(&)
  end
end
