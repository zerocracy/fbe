# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'decoor'
require 'ellipsized'
require 'faraday/http_cache'
require 'faraday/retry'
require 'filesize'
require 'intercepted'
require 'json'
require 'loog'
require 'obk'
require 'octokit'
require 'others'
require 'tago'
require 'uri'
require 'veil'
require 'verbose'
require_relative '../fbe'
require_relative 'middleware'
require_relative 'middleware/formatter'
require_relative 'middleware/rate_limit'
require_relative 'middleware/sqlite_store'
require_relative 'middleware/trace'

# When we are off quota.
class Fbe::OffQuota < StandardError; end

Fbe::SEARCH_METHODS = %i[
  search_issues search_commits search_repositories search_users search_code search_topics
].freeze

# Makes a call to the GitHub API.
#
# It is supposed to be used instead of +Octokit::Client+, because it
# is pre-configured and enables additional features, such as retrying,
# logging, and caching.
#
# @param [Judges::Options] options The options available globally
# @option options [String] :github_token GitHub API token for authentication
# @option options [Boolean] :testing When true, uses FakeOctokit for testing
# @option options [String] :sqlite_cache Path to SQLite cache file for HTTP responses
# @option options [Integer] :sqlite_cache_maxsize Maximum size of SQLite cache in bytes (default: 10MB)
# @param [Hash] global Hash of global options
# @param [Loog] loog Logging facility
# @return [Hash] Usually returns a JSON, as it comes from the GitHub API
def Fbe.octo(options: $options, global: $global, loog: $loog) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  raise(Fbe::Error, 'The $global is not set') if global.nil?
  raise(Fbe::Error, 'The $options is not set') if options.nil?
  raise(Fbe::Error, 'The $loog is not set') if loog.nil?
  global[:mutex] ||= Mutex.new
  global[:mutex].synchronize do # rubocop:disable Metrics/BlockLength
    global[:octo] ||=
      begin
        loog.info("Fbe version is #{Fbe::VERSION}")
        trace = []
        if options.testing.nil?
          o = Octokit::Client.new
          token = options.github_token
          if token.nil?
            loog.debug("The 'github_token' option is not provided")
            token = ENV.fetch('GITHUB_TOKEN', nil)
            if token.nil?
              loog.debug("The 'GITHUB_TOKEN' environment variable is not set")
            else
              loog.debug("The 'GITHUB_TOKEN' environment was provided")
            end
          else
            loog.debug("The 'github_token' option was provided (#{token.length} chars)")
          end
          if token.nil?
            loog.warn('Accessing GitHub API without a token!')
          elsif token.empty?
            loog.warn('The GitHub API token is an empty string, won\'t use it')
          else
            o = Octokit::Client.new(access_token: token)
          end
          o.auto_paginate = true
          o.per_page = 100
          o.connection_options = { request: { open_timeout: 15, timeout: 15 } }
          stack =
            Faraday::RackBuilder.new do |builder|
              builder.use(
                Faraday::Retry::Middleware,
                exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [
                  Octokit::TooManyRequests, Octokit::ServiceUnavailable
                ],
                max: 4,
                interval: ENV['RACK_ENV'] == 'test' ? 0.01 : 4,
                methods: [:get],
                backoff_factor: 2
              )
              builder.use(Octokit::Response::RaiseError)
              builder.use(Faraday::Response::Logger, loog, formatter: Fbe::Middleware::Formatter)
              builder.use(Fbe::Middleware::RateLimit)
              builder.use(Fbe::Middleware::Trace, trace, ignores: [:fresh])
              if options.sqlite_cache
                maxsize = Integer(Filesize.from(options.sqlite_cache_maxsize || '100M'))
                maxvsize = Integer(Filesize.from(options.sqlite_cache_maxvsize || '100K'))
                minage = options.sqlite_cache_min_age.nil? ? nil : Integer(options.sqlite_cache_min_age.to_s, 10)
                store = Fbe::Middleware::SqliteStore.new(
                  options.sqlite_cache, Fbe::VERSION, loog:, maxsize:, maxvsize:, ttl: 24, cache_min_age: minage
                )
                loog.info(
                  "Using HTTP cache in SQLite file: #{store.path} (" \
                  "#{File.exist?(store.path) ? Filesize.from(File.size(store.path).to_s).pretty : 'file is absent'}, " \
                  "max size: #{Filesize.from(maxsize.to_s).pretty}, max vsize: #{Filesize.from(maxvsize.to_s).pretty})"
                )
                builder.use(Faraday::HttpCache, store:, serializer: JSON, shared_cache: false, logger: Loog::NULL)
              else
                loog.info("No HTTP cache in SQLite file, because 'sqlite_cache' option is not provided")
                builder.use(Faraday::HttpCache, serializer: Marshal, shared_cache: false, logger: Loog::NULL)
              end
              builder.adapter(Faraday.default_adapter)
            end
          o.middleware = stack
          o = Verbose.new(o, log: loog)
          unless token.nil? || token.empty?
            loog.info(
              "Accessing GitHub API with a token (#{token.length} chars, ending by #{token[-4..].inspect}, " \
              "#{o.rate_limit.remaining} quota remaining)"
            )
          end
        else
          loog.debug('The connection to GitHub API is mocked')
          o = Fbe::FakeOctokit.new
        end
        o =
          decoor(o, loog:, trace:) do # rubocop:disable Metrics/BlockLength
            def print_trace!(all: false, max: 5)
              if @trace.empty?
                @loog.debug('GitHub API trace is empty')
              else
                grouped =
                  @trace.select { |e| e[:duration] > 0.05 || all }.group_by do |entry|
                    uri = URI.parse(entry[:url])
                    query = uri.query
                    query = "?#{query.ellipsized(40)}" if query
                    "#{uri.scheme}://#{uri.host}#{uri.path}#{query}"
                  end
                message = grouped
                  .sort_by { |_path, entries| -entries.count }
                  .map do |path, entries|
                    [
                      '  ',
                      path.gsub(%r{^https://api.github.com/}, '/'),
                      ': ',
                      entries.count,
                      " (#{entries.sum { |e| e[:duration] }.seconds})"
                    ].join
                  end
                  .take(max)
                  .join("\n")
                @loog.info(
                  "GitHub API trace (#{grouped.count} URLs vs #{@trace.count} requests, " \
                  "#{@origin.rate_limit!.remaining} quota left):\n#{message}"
                )
                @trace.clear
              end
            end
            def off_quota?(threshold: nil, resource: :core) # rubocop:disable Layout/EmptyLineBetweenDefs, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
              threshold ||= resource == :search ? 5 : 50
              label = resource == :search ? 'GitHub Search API' : 'GitHub API'
              left = @origin.rate_limit!.remaining
              got = false
              if resource == :search && @origin.respond_to?(:last_response)
                body = @origin.last_response&.body
                body = JSON.parse(body) if body.is_a?(String)
                if body.is_a?(Hash)
                  fresh = body.dig('resources', 'search', 'remaining') || body.dig(:resources, :search, :remaining)
                  if fresh
                    left = Integer(fresh)
                    got = true
                  end
                end
              end
              if resource == :search && !got
                klass = @origin.respond_to?(:last_response) ? @origin.last_response&.body&.class : nil
                @loog.warn(
                  "Search-quota check fell back to core remaining (#{left}); " \
                  "search count unavailable (last_response body class: #{klass.inspect})"
                )
              end
              if left < threshold
                @loog.info("Too much #{label} quota consumed already (#{left} < #{threshold})")
                true
              else
                @loog.debug("Still #{left} #{label} quota left (>#{threshold})")
                false
              end
            end
            # @see https://github.com/zerocracy/pages-action/issues/131
            def user_name_by_id(id) # rubocop:disable Layout/EmptyLineBetweenDefs
              raise(Fbe::Error, 'The ID of the user is nil') if id.nil?
              raise(Fbe::Error, 'The ID of the user must be an Integer') unless id.is_a?(Integer)
              json = @origin.user(id)
              name = json[:login].downcase
              @loog.debug("GitHub user ##{id} has a name: @#{name}")
              name
            rescue Octokit::NotFound, Octokit::Forbidden => e
              raise(Fbe::Error, "GitHub user ##{id} is not accessible: #{e.message}")
            end
            def repo_id_by_name(name) # rubocop:disable Layout/EmptyLineBetweenDefs
              raise(Fbe::Error, 'The name of the repo is nil') if name.nil?
              json = @origin.repository(name)
              id = json[:id]
              raise(Fbe::Error, "Repository #{name} not found") if id.nil?
              @loog.debug("GitHub repository #{name.inspect} has an ID: ##{id}")
              id
            end
            def repo_name_by_id(id) # rubocop:disable Layout/EmptyLineBetweenDefs
              raise(Fbe::Error, 'The ID of the repo is nil') if id.nil?
              raise(Fbe::Error, 'The ID of the repo must be an Integer') unless id.is_a?(Integer)
              json = @origin.repository(id)
              name = json[:full_name].downcase
              @loog.debug("GitHub repository ##{id} has a name: #{name}")
              name
            end
            # Disable auto pagination for octokit client called in block
            #
            # @yield [octo] Give octokit client with disabled auto pagination
            # @yieldparam [Octokit::Client, Fbe::FakeOctokit] Octokit client
            # @return [Object] Last value in block
            # @example
            #   issue =
            #      Fbe.octo.with_disable_auto_paginate do |octo|
            #        octo.list_issue('zerocracy/fbe', per_page: 1).first
            #      end
            def with_disable_auto_paginate # rubocop:disable Layout/EmptyLineBetweenDefs
              ap = @origin.auto_paginate
              @origin.auto_paginate = false
              yield(self) if block_given?
            ensure
              @origin.auto_paginate = ap
            end
          end
        o =
          intercepted(o) do |e, m, _args, _r|
            next unless e == :before
            next if %i[off_quota? print_trace! rate_limit].include?(m)
            if Fbe::SEARCH_METHODS.include?(m)
              raise(Fbe::OffQuota, "We are off-quota on the search resource, can't do #{m}()") if
                o.off_quota?(resource: :search)
            elsif o.off_quota?
              raise(Fbe::OffQuota, "We are off-quota (remaining: #{o.rate_limit.remaining}), can't do #{m}()")
            end
          end
        o.instance_eval do
          def send(...)
            __send__(...)
          end
          def public_send(...) # rubocop:disable Layout/EmptyLineBetweenDefs, Elegant/GoodMethodName
            __send__(...)
          end
        end
        o
      end
  end
end

require_relative 'fake_octokit'
