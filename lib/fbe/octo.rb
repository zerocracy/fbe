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
def Fbe.octo(options: $options, global: $global, loog: $loog)
  raise 'The $global is not set' if global.nil?
  raise 'The $options is not set' if options.nil?
  raise 'The $loog is not set' if loog.nil?
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
        o.connection_options = {
          request: {
            open_timeout: 15,
            timeout: 15
          }
        }
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
              maxsize = Filesize.from(options.sqlite_cache_maxsize || '100M').to_i
              maxvsize = Filesize.from(options.sqlite_cache_maxvsize || '100K').to_i
              cache_min_age = options.sqlite_cache_min_age&.to_i
              store = Fbe::Middleware::SqliteStore.new(
                options.sqlite_cache, Fbe::VERSION, loog:, maxsize:, maxvsize:, ttl: 24, cache_min_age:
              )
              loog.info(
                "Using HTTP cache in SQLite file: #{store.path} (" \
                "#{File.exist?(store.path) ? Filesize.from(File.size(store.path).to_s).pretty : 'file is absent'}, " \
                "max size: #{Filesize.from(maxsize.to_s).pretty}, max vsize: #{Filesize.from(maxvsize.to_s).pretty})"
              )
              builder.use(
                Faraday::HttpCache,
                store:, serializer: JSON, shared_cache: false, logger: Loog::NULL
              )
            else
              loog.info("No HTTP cache in SQLite file, because 'sqlite_cache' option is not provided")
              builder.use(
                Faraday::HttpCache,
                serializer: Marshal, shared_cache: false, logger: Loog::NULL
              )
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
        decoor(o, loog:, trace:) do
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

          def off_quota?(threshold: 50)
            left = @origin.rate_limit!.remaining
            if left < threshold
              @loog.info("Too much GitHub API quota consumed already (#{left} < #{threshold})")
              true
            else
              @loog.debug("Still #{left} GitHub API quota left (>#{threshold})")
              false
            end
          end

          def user_name_by_id(id)
            raise 'The ID of the user is nil' if id.nil?
            raise 'The ID of the user must be an Integer' unless id.is_a?(Integer)
            json = @origin.user(id)
            name = json[:login].downcase
            @loog.debug("GitHub user ##{id} has a name: @#{name}")
            name
          end

          def repo_id_by_name(name)
            raise 'The name of the repo is nil' if name.nil?
            json = @origin.repository(name)
            id = json[:id]
            raise "Repository #{name} not found" if id.nil?
            @loog.debug("GitHub repository #{name.inspect} has an ID: ##{id}")
            id
          end

          def repo_name_by_id(id)
            raise 'The ID of the repo is nil' if id.nil?
            raise 'The ID of the repo must be an Integer' unless id.is_a?(Integer)
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
          def with_disable_auto_paginate
            ap = @origin.auto_paginate
            @origin.auto_paginate = false
            yield self if block_given?
          ensure
            @origin.auto_paginate = ap
          end
        end
      o =
        intercepted(o) do |e, m, _args, _r|
          if e == :before && m != :off_quota? && m != :print_trace! && m != :rate_limit && o.off_quota?
            raise Fbe::OffQuota, "We are off-quota (remaining: #{o.rate_limit.remaining}), can't do #{m}()"
          end
        end
      o
    end
end

# Fake GitHub client for testing purposes.
#
# This class provides mock implementations of Octokit methods for testing.
# It returns predictable, deterministic data structures that mimic GitHub API
# responses without making actual API calls. The mock data uses consistent
# patterns:
# - IDs are generated from string names using character code sums
# - Timestamps are random but within recent past
# - Repository and user data follows GitHub's JSON structure
#
# @example Using FakeOctokit in tests
#   client = Fbe::FakeOctokit.new
#   repo = client.repository('octocat/hello-world')
#   puts repo[:full_name]  # => "octocat/hello-world"
#   puts repo[:id]         # => 1224 (deterministic from name)
#
# @note All methods return static or pseudo-random data
# @note No actual API calls are made
class Fbe::FakeOctokit
  # Generates a random time in the past.
  #
  # @return [Time] A random time within the last 10,000 seconds
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   time = fake_client.random_time #=> 2024-09-04 12:34:56 -0700
  def random_time
    Time.now - rand(10_000)
  end

  # Converts a string name to a deterministic integer.
  #
  # @param [String, Integer] name The name to convert or pass through
  # @return [Integer, String] The sum of character codes if input is a string, otherwise the original input
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.name_to_number("octocat") #=> 728
  #   fake_client.name_to_number(42) #=> 42
  def name_to_number(name)
    return name unless name.is_a?(String)
    name.chars.sum(&:ord)
  end

  def auto_paginate=(_); end

  def auto_paginate; end

  # Returns a mock rate limit object.
  #
  # @return [Object] An object with a remaining method that returns 100
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.rate_limit.remaining #=> 100
  def rate_limit
    Veil.new(nil, remaining: 100)
  end

  alias rate_limit! rate_limit

  # Lists repositories for a user or organization.
  #
  # @param [String] _user The user/org name (ignored in mock)
  # @return [Array<Hash>] Array of repository hashes
  # @example
  #   client.repositories('octocat')
  #   # => [{:id=>123, :full_name=>"yegor256/judges", ...}, ...]
  def repositories(_user = nil)
    [
      repository('yegor256/judges'),
      repository('yegor256/factbase')
    ]
  end

  # Gets repository invitations for the authenticated user.
  #
  # @param [Hash] _options Additional options (not used in mock)
  # @return [Array<Hash>] Array of invitation objects with repository and inviter information
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.user_repository_invitations #=> [{:id=>1, :node_id=>"INV_", ...}]
  def user_repository_invitations(_options = {})
    [
      {
        id: 1,
        node_id: 'INV_kwDOJRF-Hq4B_yXr',
        repository: repository('zerocracy/fbe'),
        invitee: user(526_301),
        inviter: user(888),
        permissions: 'write',
        created_at: random_time,
        url: 'https://api.github.com/user/repository_invitations/1',
        html_url: 'https://github.com/zerocracy/fbe/invitations',
        expired: false
      },
      {
        id: 2,
        node_id: 'INV_kwDOJRF-Hq4B_yXs',
        repository: repository('yegor256/takes'),
        invitee: user(526_301),
        inviter: user(888),
        permissions: 'admin',
        created_at: random_time,
        url: 'https://api.github.com/user/repository_invitations/2',
        html_url: 'https://github.com/yegor256/takes/invitations',
        expired: false
      }
    ]
  end

  # Gets organization memberships for the authenticated user.
  #
  # @param [Hash] _options Additional options (not used in mock)
  # @return [Array<Hash>] Array of organization membership objects
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.organization_memberships #=> [{:url=>"https://api.github.com/orgs/...", ...}]
  def organization_memberships(_options = {})
    [
      {
        url: 'https://api.github.com/orgs/zerocracy/memberships/yegor256',
        state: 'active',
        role: 'admin',
        organization_url: 'https://api.github.com/orgs/zerocracy',
        organization: {
          login: 'zerocracy',
          id: 24_234_201,
          node_id: 'MDEyOk9yZ2FuaXphdGlvbjI0MjM0MjAx',
          url: 'https://api.github.com/orgs/zerocracy',
          avatar_url: 'https://avatars.githubusercontent.com/u/24234201?v=4',
          description: 'AI-managed software development',
          name: 'Zerocracy',
          company: nil,
          blog: 'https://www.zerocracy.com',
          location: nil,
          email: 'team@zerocracy.com',
          twitter_username: nil,
          is_verified: false,
          has_organization_projects: true,
          has_repository_projects: true,
          public_repos: 30,
          public_gists: 0,
          followers: 0,
          following: 0,
          html_url: 'https://github.com/zerocracy',
          created_at: random_time,
          updated_at: random_time,
          type: 'Organization'
        },
        user: user(526_301)
      },
      {
        url: 'https://api.github.com/orgs/objectionary/memberships/yegor256',
        state: 'active',
        role: 'member',
        organization_url: 'https://api.github.com/orgs/objectionary',
        organization: {
          login: 'objectionary',
          id: 80_033_603,
          node_id: 'MDEyOk9yZ2FuaXphdGlvbjgwMDMzNjAz',
          url: 'https://api.github.com/orgs/objectionary',
          avatar_url: 'https://avatars.githubusercontent.com/u/80033603?v=4',
          description: 'EO/EOLANG, an object-oriented language',
          name: 'Objectionary',
          company: nil,
          blog: 'https://www.eolang.org',
          location: nil,
          email: nil,
          twitter_username: nil,
          is_verified: false,
          has_organization_projects: true,
          has_repository_projects: true,
          public_repos: 15,
          public_gists: 0,
          followers: 0,
          following: 0,
          html_url: 'https://github.com/objectionary',
          created_at: random_time,
          updated_at: random_time,
          type: 'Organization'
        },
        user: user(526_301)
      }
    ]
  end

  # Updates the authenticated user's organization membership.
  #
  # @param [String] org The organization name (e.g., 'zerocracy')
  # @param [Hash] _options Additional options (typically includes :state to update membership state)
  # @return [Hash] Updated membership information
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.update_organization_membership('zerocracy', state: 'active')
  def update_organization_membership(org, _options = {})
    {
      url: "https://api.github.com/orgs/#{org}/memberships/yegor256",
      state: 'active',
      role: 'member',
      organization_url: "https://api.github.com/orgs/#{org}",
      organization: {
        login: org,
        id: 24_234_201,
        node_id: 'MDEyOk9yZ2FuaXphdGlvbjI0MjM0MjAx',
        url: "https://api.github.com/orgs/#{org}",
        avatar_url: 'https://avatars.githubusercontent.com/u/24234201?v=4',
        description: 'Organization description',
        name: org.capitalize,
        company: nil,
        blog: "https://www.#{org}.com",
        location: nil,
        email: "team@#{org}.com",
        twitter_username: nil,
        is_verified: false,
        has_organization_projects: true,
        has_repository_projects: true,
        public_repos: 30,
        public_gists: 0,
        followers: 0,
        following: 0,
        html_url: "https://github.com/#{org}",
        created_at: random_time,
        updated_at: random_time,
        type: 'Organization'
      },
      user: user(526_301)
    }
  end

  # Removes a user from an organization.
  #
  # @param [String] _org The organization name (e.g., 'zerocracy')
  # @param [String] _user The user login (not used in this mock implementation)
  # @return [Boolean] Returns true when successful (204 No Content in actual API)
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.remove_organization_membership('zerocracy') #=> true
  # rubocop:disable Naming/PredicateMethod
  def remove_organization_membership(_org, _user = nil)
    true
  end
  # rubocop:enable Naming/PredicateMethod

  # Accepts a repository invitation.
  #
  # @param [Integer] id The invitation ID
  # @return [Boolean] Returns true when successful (204 No Content in actual API)
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.accept_repository_invitation(1) #=> true
  # rubocop:disable Naming/PredicateMethod
  def accept_repository_invitation(id)
    raise Octokit::NotFound if id == 404_000
    true
  end
  # rubocop:enable Naming/PredicateMethod

  # Gives a star to a repository.
  #
  # @param [String] _repo The repository name (e.g., 'user/repo')
  # @return [Boolean] Always returns true
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.star('octocat/Hello-World') #=> true
  # rubocop:disable Naming/PredicateMethod
  def star(_repo)
    true
  end
  # rubocop:enable Naming/PredicateMethod

  # Gets details of a GitHub user.
  #
  # @param [String, Integer] uid The login of the user or its numeric ID
  # @return [Hash] User information including id, login, and type
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   fake_client.user(526_301) #=> {:id=>444, :login=>"yegor256", :type=>"User"}
  #   fake_client.user('octocat') #=> {:id=>444, :login=>nil, :type=>"User"}
  def user(uid)
    raise Octokit::NotFound if [404_001, 404_002].include?(uid)
    login = (uid == 526_301 ? 'yegor256' : 'torvalds') if uid.is_a?(Integer)
    {
      id: 444,
      login:,
      type: uid == 29_139_614 ? 'Bot' : 'User'
    }
  end

  # Gets workflow runs for a repository.
  #
  # @param [String] repo The repository name
  # @param [Hash] _opts Additional options (not used in mock)
  # @return [Hash] Information about workflow runs including counts and details
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   result = fake_client.repository_workflow_runs('octocat/Hello-World')
  #   result[:total_count] #=> 2
  def repository_workflow_runs(repo, _opts = {})
    {
      total_count: 2,
      workflow_runs: [
        workflow_run(repo, 42),
        workflow_run(repo, 7)
      ]
    }
  end

  # Gets usage information for a specific workflow run.
  #
  # @param [String] _repo The repository name
  # @param [Integer] _id The workflow run ID
  # @return [Hash] Billing and usage information for the workflow run
  # @example
  #   fake_client = Fbe::FakeOctokit.new
  #   usage = fake_client.workflow_run_usage('octocat/Hello-World', 42)
  #   usage[:run_duration_ms] #=> 53000
  def workflow_run_usage(_repo, _id)
    {
      billable: {
        UBUNTU: {
          total_ms: 0,
          jobs: 1,
          job_runs: [
            {
              job_id: 1,
              duration_ms: 0
            }
          ]
        }
      },
      run_duration_ms: 53_000
    }
  end

  # Lists releases for a repository.
  #
  # @param [String] _repo Repository name (ignored in mock)
  # @param [Hash] _opts Options hash (ignored in mock)
  # @return [Array<Hash>] Array of release hashes
  # @example
  #   client.releases('octocat/Hello-World')
  #   # => [{:tag_name=>"0.19.0", :name=>"just a fake name", ...}, ...]
  def releases(_repo, _opts = {})
    [
      release('https://github...'),
      release('https://gith')
    ]
  end

  # Gets a single release.
  #
  # @param [String] _url Release URL (ignored in mock)
  # @return [Hash] Release information
  # @example
  #   client.release('https://api.github.com/repos/octocat/Hello-World/releases/1')
  #   # => {:tag_name=>"0.19.0", :name=>"just a fake name", ...}
  def release(_url)
    {
      node_id: 'RE_kwDOL6GCO84J7Cen',
      tag_name: '0.19.0',
      target_commitish: 'master',
      name: 'just a fake name',
      draft: false,
      prerelease: false,
      created_at: random_time,
      published_at: random_time,
      assets: []
    }
  end

  # Gets repository information.
  #
  # @param [String, Integer] name Repository name ('owner/repo') or ID
  # @return [Hash] Repository information
  # @raise [Octokit::NotFound] If name is 404123 or 404124 (for testing)
  # @example
  #   client.repository('octocat/Hello-World')
  #   # => {:id=>1296269, :full_name=>"octocat/Hello-World", ...}
  def repository(name)
    raise Octokit::NotFound if [404_123, 404_124].include?(name)
    full_name = name.is_a?(Integer) ? 'yegor256/test' : name
    full_name = 'zerocracy/baza' if name == 1439
    full_name = 'foo/bazz' if name == 810
    size =
      case name
      when 'yegor256/empty-repo' then 0
      when 'yegor256/nil-size-repo' then nil
      else 470
      end
    {
      id: name_to_number(name),
      full_name:,
      default_branch: 'master',
      private: false,
      owner: { login: name.to_s.split('/')[0], id: 526_301, site_admin: false },
      html_url: "https://github.com/#{name}",
      description: 'something',
      fork: false,
      url: "https://github.com/#{name}",
      created_at: random_time,
      updated_at: random_time,
      pushed_at: random_time,
      size:,
      stargazers_count: 1,
      watchers_count: 1,
      language: 'Ruby',
      has_issues: true,
      has_projects: true,
      has_downloads: true,
      has_wiki: true,
      has_pages: false,
      has_discussions: false,
      forks_count: 0,
      archived: name == 'zerocracy/datum',
      disabled: false,
      open_issues_count: 6,
      license: { key: 'mit', name: 'MIT License' },
      allow_forking: true,
      is_template: false,
      visibility: 'public',
      forks: 0,
      open_issues: 6,
      watchers: 1
    }
  end

  # Lists pull requests associated with a commit.
  #
  # @param [String] repo Repository name ('owner/repo')
  # @param [String] _sha Commit SHA (ignored in mock)
  # @return [Array<Hash>] Array of pull request hashes
  # @example
  #   client.commit_pulls('octocat/Hello-World', 'abc123')
  #   # => [{:number=>42, :state=>"open", ...}]
  def commit_pulls(repo, _sha)
    [
      pull_request(repo, 42)
    ]
  end

  # Lists issues for a repository.
  #
  # @param [String] repo Repository name ('owner/repo')
  # @param [Hash] _options Query options (ignored in mock)
  # @return [Array<Hash>] Array of issue hashes
  # @example
  #   client.list_issues('octocat/Hello-World', state: 'open')
  #   # => [{:number=>42, :title=>"Found a bug", ...}, ...]
  def list_issues(repo, _options = {})
    [
      issue(repo, 42),
      issue(repo, 43)
    ].tap do |list|
      list.prepend(issue(repo, 144)) if repo == 'foo/bazz'
    end
  end

  # Gets a single issue.
  #
  # @param [String] repo Repository name ('owner/repo')
  # @param [Integer] number Issue number
  # @return [Hash] Issue information
  # @example
  #   client.issue('octocat/Hello-World', 42)
  #   # => {:id=>42, :number=>42, :created_at=>...}
  def issue(repo, number)
    case number
    when 94
      {
        id: 42,
        number:,
        repo: {
          full_name: repo
        },
        pull_request: {
          merged_at: nil
        },
        created_at: Time.parse('2024-09-20 19:00:00 UTC')
      }
    when 142
      {
        id: 655,
        number:,
        repo: { full_name: repo },
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        state: 'closed',
        created_at: Time.parse('2025-06-01 12:00:55 UTC'),
        updated_at: Time.parse('2025-06-01 15:47:18 UTC'),
        closed_at: Time.parse('2025-06-02 15:00:00 UTC'),
        closed_by: { id: 526_301, login: 'yegor256' }
      }
    when 143
      {
        id: 656,
        number:,
        repo: { full_name: repo },
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        pull_request: { merged_at: nil },
        state: 'closed',
        created_at: Time.parse('2025-05-29 17:00:55 UTC'),
        updated_at: Time.parse('2025-05-29 19:00:00 UTC'),
        closed_at: Time.parse('2025-06-01 18:20:00 UTC'),
        closed_by: { id: 526_301, login: 'yegor256' }
      }
    when 144
      {
        id: 657,
        number:,
        repo: { full_name: repo },
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        pull_request: { merged_at: nil },
        created_at: Time.parse('2025-05-29 17:00:55 UTC')
      }
    else
      {
        id: 42,
        number:,
        repo: {
          full_name: repo
        },
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        pull_request: {
          merged_at: nil
        },
        created_at: Time.parse('2024-09-20 19:00:00 UTC')
      }
    end
  end

  # Gets a single pull request.
  #
  # @param [String] repo Repository name ('owner/repo')
  # @param [Integer] number Pull request number
  # @return [Hash] Pull request information
  # @example
  #   client.pull_request('octocat/Hello-World', 1)
  #   # => {:id=>42, :number=>1, :additions=>12, ...}
  def pull_request(repo, number)
    if number == 29
      {
        id: 42,
        number:,
        user: { id: 421, login: 'user' },
        created_at: Time.parse('2024-08-20 15:35:30 UTC'),
        additions: 12,
        deletions: 5
      }
    elsif number == 172
      {
        id: 1_990_323_142,
        number: 172,
        url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
        node_id: 'PR_kwDOL6GCO852oevG',
        state: 'closed',
        locked: false,
        title: '#999 new feature',
        user: {
          login: 'test',
          id: 88_084_038,
          node_id: 'MDQ6VXNlcjE2NDYwMjA=',
          type: 'User',
          site_admin: false
        },
        base: {
          ref: 'master',
          sha: '125f234967de0f690805c6943e78db42a294c1a',
          repo: { id: repo, name: 'judges' }
        },
        head: {
          ref: 'zerocracy/judges',
          sha: '74d0c234967de0f690805c6943e78db42a294c1a'
        },
        merged_at: Time.now,
        comments: 2,
        review_comments: 2,
        commits: 1,
        additions: 3,
        deletions: 3,
        changed_files: 2
      }
    else
      {
        id: 42,
        number:,
        repo: {
          full_name: repo
        },
        base: {
          repo: {
            full_name: repo
          }
        },
        state: 'closed',
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        head: { ref: 'master', sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e' },
        additions: 12,
        deletions: 5,
        changed_files: 3,
        comments: 2,
        review_comments: 2,
        closed_at: Time.parse('2024-12-20'),
        merged_at: Time.parse('2024-12-20'),
        created_at: Time.parse('2024-09-20')
      }
    end
  end

  # Lists pull requests for a repository.
  #
  # @param [String] _repo Repository name (ignored in mock)
  # @param [Hash] _options Query options (ignored in mock)
  # @return [Array<Hash>] Array of pull request hashes
  # @example
  #   client.pull_requests('octocat/Hello-World', state: 'open')
  #   # => [{:number=>100, :state=>"closed", :title=>"#90: some title", ...}]
  def pull_requests(_repo, _options = {})
    [
      {
        id: 2_072_543_250,
        number: 100,
        state: 'closed',
        locked: false,
        title: '#90: some title',
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        body: 'Closes #90',
        created_at: Time.parse('2024-09-15 09:32:49 UTC'),
        updated_at: Time.parse('2024-09-15 10:06:23 UTC'),
        closed_at: Time.parse('2024-09-15 10:05:34 UTC'),
        merged_at: Time.parse('2024-09-15 10:05:34 UTC'),
        merge_commit_sha: '0527cc188b0495e',
        draft: false,
        head: {
          label: 'yegor256:90',
          ref: '90',
          sha: '0527cc188b049',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          repo: repository('yegor256/repo')
        },
        base: {
          label: 'zerocracy:master',
          ref: 'master',
          sha: '4643eb3c7a0ccb3c',
          user: { login: 'zerocracy', id: 24_234_201, type: 'Organization' },
          repo: repository('zerocracy/repo')
        }
      },
      {
        id: 2_072_543_240,
        number: 95,
        state: 'open',
        locked: false,
        title: '#80: some title',
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        body: 'Closes #80',
        created_at: Time.parse('2024-09-14 09:32:49 UTC'),
        updated_at: Time.parse('2024-09-14 10:06:23 UTC'),
        closed_at: nil,
        merged_at: nil,
        merge_commit_sha: '0627cc188b0497e',
        draft: false,
        head: {
          label: 'yegor256:80',
          ref: '80',
          sha: '1527cc188b040',
          user: { login: 'yegor256', id: 526_301, type: 'User' },
          repo: repository('yegor256/repo')
        },
        base: {
          label: 'zerocracy:master',
          ref: 'master',
          sha: '5643eb3c7a0ccb3b',
          user: { login: 'zerocracy', id: 24_234_201, type: 'Organization' },
          repo: repository('zerocracy/repo')
        }
      }
    ]
  end

  def pull_request_reviews(_repo, _number)
    [
      {
        id: 22_449_327,
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        body: 'Some text 2',
        state: 'CHANGES_REQUESTED',
        author_association: 'CONTRIBUTOR',
        submitted_at: Time.parse('2024-08-22 10:00:00 UTC'),
        commit_id: 'b15c2893f1b5453'
      },
      {
        id: 22_449_326,
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        body: 'Some text 1',
        state: 'CHANGES_REQUESTED',
        author_association: 'CONTRIBUTOR',
        submitted_at: Time.parse('2024-08-21 22:00:00 UTC'),
        commit_id: 'a15c2893f1b5453'
      }
    ]
  end

  def pull_request_review_comments(_repo, _number, _review, _options = {})
    [
      { id: 22_447_120, user: { login: 'yegor256', id: 526_301, type: 'User' } },
      { id: 22_447_121, user: { login: 'yegor256', id: 526_301, type: 'User' } }
    ]
  end

  def review_comments(_repo, _number)
    [
      {
        pull_request_review_id: 22_687_249,
        id: 17_361_949,
        body: 'Some comment 1',
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        created_at: Time.parse('2024-09-05 15:31:06 UTC'),
        updated_at: Time.parse('2024-09-05 15:33:04 UTC')
      },
      {
        pull_request_review_id: 22_687_503,
        id: 17_361_950,
        body: 'Some comment 2',
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        created_at: Time.parse('2024-09-06 14:20:00 UTC'),
        updated_at: Time.parse('2024-09-06 14:20:50 UTC')
      },
      {
        pull_request_review_id: 22_687_255,
        id: 17_361_970,
        body: 'Some comment 3',
        user: { login: 'yegor256', id: 526_301, type: 'User' },
        created_at: Time.parse('2024-09-06 20:45:30 UTC'),
        updated_at: Time.parse('2024-09-06 20:45:30 UTC')
      }
    ]
  end

  def add_comment(_repo, _issue, _text)
    {
      id: 42
    }
  end

  def create_commit_comment(_repo, sha, text)
    {
      commit_id: sha,
      id: 42,
      body: text,
      path: 'something.txt',
      line: 1,
      position: 1
    }
  end

  def search_issues(query, _options = {})
    if query.include?('type:pr') && query.include?('is:unmerged')
      {
        total_count: 1,
        incomplete_results: false,
        items: [
          {
            id: 42,
            number: 10,
            title: 'Awesome PR 10'
          }
        ]
      }
    elsif query.include?('type:pr') && query.include?('is:merged')
      {
        total_count: 1,
        incomplete_results: false,
        items: [
          {
            id: 42,
            number: 10,
            title: 'Awesome PR 10',
            created_at: Time.parse('2024-08-21 19:00:00 UTC'),
            pull_request: { merged_at: Time.parse('2024-08-23 19:00:00 UTC') }
          }
        ]
      }
    elsif query.include?('type:pr')
      {
        total_count: 2,
        incomplete_results: false,
        items: [
          {
            id: 42,
            number: 10,
            title: 'Awesome PR 10',
            created_at: Time.parse('2024-08-21 19:00:00 UTC')
          },
          {
            id: 43,
            number: 11,
            title: 'Awesome PR 11',
            created_at: Time.parse('2024-08-21 20:00:00 UTC')
          }
        ]
      }
    else
      {
        total_count: 1,
        incomplete_results: false,
        items: [
          {
            number: 42,
            labels: [
              {
                name: 'bug'
              }
            ],
            user: { login: 'yegor256', id: 526_301, type: 'User' },
            created_at: Time.parse('2024-08-20 19:00:00 UTC')
          }
        ]
      }
    end
  end

  def commits_since(repo, _since)
    [
      commit(repo, 'a1b2c3d4e5f6a1b2c3d4e5f6'),
      commit(repo, 'a1b2c3d4e5fff1b2c3d4e5f6')
    ]
  end

  def commit(_repo, sha)
    {
      sha:,
      stats: {
        total: 123
      }
    }
  end

  def search_commits(_query, _options = {})
    {
      total_count: 3,
      incomplete_results: false,
      items: [
        {
          commit: {
            author: { name: 'Yegor', email: 'yegor@gmail.com', date: Time.parse('2024-09-15 12:23:25 UTC') },
            committer: { name: 'Yegor', email: 'yegor@gmail.com', date: Time.parse('2024-09-15 12:23:25 UTC') },
            message: 'Some text',
            tree: { sha: '6e04579960bf67610d' },
            comment_count: 0
          },
          author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          committer: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          parents: [{ sha: '60cff20bdb66' }],
          repository: {
            id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
            owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
          }
        },
        {
          commit: {
            author: { name: 'Yegor', email: 'yegor2@gmail.com', date: Time.parse('2024-09-14 12:23:25 UTC') },
            committer: { name: 'Yegor', email: 'yegor2@gmail.com', date: Time.parse('2024-09-14 12:23:25 UTC') },
            message: 'Some text 2',
            tree: { sha: 'defa18e4e2250987' },
            comment_count: 0
          },
          author: { login: 'yegor257', id: 526_302, type: 'User', site_admin: false },
          committer: { login: 'yegor257', id: 526_302, type: 'User', site_admin: false },
          parents: [{ sha: 'a04c15bb34fddbba' }],
          repository: {
            id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
            owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
          }
        },
        {
          commit: {
            author: { name: 'Yegor', email: 'yegor3@gmail.com', date: Time.parse('2024-09-13 12:23:25 UTC') },
            committer: { name: 'Yegor', email: 'yegor3@gmail.com', date: Time.parse('2024-09-13 12:23:25 UTC') },
            message: 'Some text 3',
            tree: { sha: 'bb7277441139739b902a' },
            comment_count: 0
          },
          author: { login: 'yegor258', id: 526_303, type: 'User', site_admin: false },
          committer: { login: 'yegor258', id: 526_303, type: 'User', site_admin: false },
          parents: [{ sha: '18db84d469bb727' }],
          repository: {
            id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
            owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
          }
        }
      ]
    }
  end

  def issue_timeline(_repo, _issue, _options = {})
    [
      {
        event: 'renamed',
        actor: {
          id: 888,
          login: 'torvalds'
        },
        repository: {
          id: name_to_number('yegor256/judges'),
          full_name: 'yegor256/judges'
        },
        rename: {
          from: 'before',
          to: 'after'
        },
        created_at: random_time
      },
      {
        event: 'labeled',
        actor: {
          id: 888,
          login: 'torvalds'
        },
        repository: {
          id: name_to_number('yegor256/judges'),
          full_name: 'yegor256/judges'
        },
        label: {
          name: 'bug'
        },
        created_at: random_time
      },
      {
        node_id: 'ITAE_examplevq862Ga8lzwAAAAQZanzv',
        event: 'issue_type_added',
        actor: {
          id: 526_301,
          login: 'yegor256'
        },
        repository: {
          id: name_to_number('yegor256/judges'),
          full_name: 'yegor256/judges'
        },
        created_at: random_time
      },
      {
        node_id: 'ITCE_examplevq862Ga8lzwAAAAQZbq9S',
        event: 'issue_type_changed',
        actor: {
          id: 526_301,
          login: 'yegor256'
        },
        repository: {
          id: name_to_number('yegor256/judges'),
          full_name: 'yegor256/judges'
        },
        created_at: random_time
      }
    ]
  end

  def repository_events(repo, _options = {})
    [
      {
        id: '123',
        type: 'PushEvent',
        repo: {
          id: name_to_number(repo),
          name: repo,
          url: "https://api.github.com/repos/#{repo}"
        },
        payload: {
          push_id: 42,
          ref: 'refs/heads/master',
          head: 'b7089c51cc2526a0d2619d35379f921d53c72731',
          before: '12d3bff1a55bad50ee2e8f29ade7f1c1e07bb025'
        },
        actor: {
          id: 888,
          login: 'torvalds',
          display_login: 'torvalds'
        },
        created_at: random_time,
        public: true
      },
      {
        id: '124',
        type: 'IssuesEvent',
        repo: {
          id: name_to_number(repo),
          name: repo,
          url: "https://api.github.com/repos/#{repo}"
        },
        payload: {
          action: 'closed',
          issue: {
            number: 42
          }
        },
        actor: {
          id: 888,
          login: 'torvalds',
          display_login: 'torvalds'
        },
        created_at: random_time,
        public: true
      },
      {
        id: '125',
        type: 'IssuesEvent',
        repo: {
          id: name_to_number(repo),
          name: repo,
          url: "https://api.github.com/repos/#{repo}"
        },
        payload: {
          action: 'opened',
          issue: {
            number: 42
          }
        },
        actor: {
          id: 888,
          login: 'torvalds',
          display_login: 'torvalds'
        },
        created_at: random_time,
        public: true
      },
      {
        id: 42,
        created_at: Time.now,
        actor: { id: 42 },
        type: 'PullRequestEvent',
        repo: { id: repo },
        payload: {
          action: 'closed',
          number: 172,
          pull_request: {
            url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
            id: 1_990_323_142,
            number: 172,
            base: {
              ref: 'master',
              sha: '93fe488b9967de0f690805c6943e78db42a294c1a',
              repo: {
                id: repo,
                name: 'baza'
              }
            },
            head: {
              ref: 'zerocracy/baza',
              sha: '74d0c234967de0f690805c6943e78db42a294c1a'
            }
          }
        }
      },
      {
        id: 43,
        created_at: Time.now,
        actor: { id: 42 },
        type: 'PullRequestEvent',
        repo: { id: repo },
        payload: {
          action: 'closed',
          number: 172,
          pull_request: {
            url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
            id: 1_990_323_142,
            number: 172,
            base: {
              ref: 'master',
              sha: '125f234967de0f690805c6943e78db42a294c1a',
              repo: {
                id: repo,
                name: 'judges-action'
              }
            },
            head: {
              ref: 'zerocracy/judges-action',
              sha: '74d0c234967de0f690805c6943e78db42a294c1a'
            }
          }
        }
      }
    ]
  end

  def issue_events(_repo, number)
    if number == 120
      [
        {
          id: 1010, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'assigned', created_at: Time.parse('2025-10-27 14:00:00 UTC'),
          assignee: { login: 'user2', id: 422, type: 'User' },
          assigner: { login: 'user', id: 411, type: 'User' }
        },
        {
          id: 1011, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'unassigned', created_at: Time.parse('2025-10-27 15:00:00 UTC'),
          assignee: { login: 'user2', id: 422, type: 'User' },
          assigner: { login: 'user', id: 411, type: 'User' }
        }
      ]
    else
      [
        {
          id: 126, actor: { login: 'user', id: 411, type: 'User' },
          event: 'labeled', created_at: Time.parse('2025-05-30 14:41:00 UTC'),
          label: { name: 'bug', color: 'd73a4a' }
        },
        {
          id: 206, actor: { login: 'user', id: 411, type: 'User' },
          event: 'mentioned', created_at: Time.parse('2025-05-30 14:41:10 UTC')
        },
        {
          id: 339, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'subscribed', created_at: Time.parse('2025-05-30 14:41:10 UTC')
        },
        {
          id: 490, actor: { login: 'github-actions[bot]', id: 41_898_282, type: 'Bot' },
          event: 'renamed', created_at: Time.parse('2025-05-30 14:41:30 UTC'),
          rename: { from: 'some title', to: 'some title 2' }
        },
        {
          id: 505, actor: { login: 'user', id: 411, type: 'User' },
          event: 'subscribed', created_at: Time.parse('2025-05-30 16:18:24 UTC')
        },
        {
          id: 608, actor: { login: 'user2', id: 422, type: 'User', test: 123 },
          event: 'assigned', created_at: Time.parse('2025-05-30 17:59:08 UTC'),
          assignee: { login: 'user2', id: 422, type: 'User' },
          assigner: { login: 'user', id: 411, type: 'User' }
        },
        {
          id: 776, actor: { login: 'user2', id: 422, type: 'User' },
          event: 'referenced', commit_id: '4621af032170f43d',
          commit_url: 'https://api.github.com/repos/foo/foo/commits/4621af032170f43d',
          created_at: Time.parse('2025-05-30 19:57:50 UTC')
        }
      ]
    end
  end

  def pull_request_comments(_name, _number)
    [
      {
        pull_request_review_id: 2_227_372_510,
        id: 1_709_082_318,
        path: 'test/baza/test_locks.rb',
        commit_id: 'a9f5f94cf28f29a64d5dd96d0ee23b4174572847',
        original_commit_id: 'e8c6f94274d14ed3cb26fe71467a9c3f229df59c',
        user: {
          login: 'Reviewer',
          id: 2_566_462
        },
        body: 'Most likely, parentheses were missed here.',
        created_at: '2024-08-08T09:41:46Z',
        updated_at: '2024-08-08T09:42:46Z',
        reactions: {
          url: 'https://api.github.com/repos/zerocracy/baza/pulls/comments/1709082318/reactions',
          total_count: 0
        },
        start_line: 'null',
        original_start_line: 'null',
        start_side: 'null',
        line: 'null',
        original_line: 62,
        side: 'RIGHT',
        original_position: 25,
        position: 'null',
        subject_type: 'line'
      },
      {
        pull_request_review_id: 2_227_372_510,
        id: 1_709_082_319,
        path: 'test/baza/test_locks.rb',
        commit_id: 'a9f5f94cf28f29a64d5dd96d0ee23b4174572847',
        original_commit_id: 'e8c6f94274d14ed3cb26fe71467a9c3f229df59c',
        user: {
          login: 'test',
          id: 88_084_038
        },
        body: 'definitely a typo',
        created_at: '2024-08-08T09:42:46Z',
        updated_at: '2024-08-08T09:42:46Z',
        reactions: {
          url: 'https://api.github.com/repos/zerocracy/baza/pulls/comments/1709082319/reactions',
          total_count: 0
        },
        start_line: 'null',
        original_start_line: 'null',
        start_side: 'null',
        line: 'null',
        original_line: 62,
        side: 'RIGHT',
        original_position: 25,
        in_reply_to_id: 1_709_082_318,
        position: 'null',
        subject_type: 'line'
      }
    ]
  end

  def issue_comments(_name, _number)
    [
      {
        pull_request_review_id: 2_227_372_510,
        id: 1_709_082_320,
        path: 'test/baza/test_locks.rb',
        commit_id: 'a9f5f94cf28f29a64d5dd96d0ee23b4174572847',
        original_commit_id: 'e8c6f94274d14ed3cb26fe71467a9c3f229df59c',
        user: {
          login: 'Reviewer',
          id: 2_566_462
        },
        body: 'reviewer comment',
        created_at: '2024-08-08T09:41:46Z',
        updated_at: '2024-08-08T09:42:46Z',
        reactions: {
          url: 'https://api.github.com/repos/zerocracy/baza/pulls/comments/1709082320/reactions',
          total_count: 1
        },
        start_line: 'null',
        original_start_line: 'null',
        start_side: 'null',
        line: 'null',
        original_line: 62,
        side: 'RIGHT',
        original_position: 25,
        position: 'null',
        subject_type: 'line'
      },
      {
        pull_request_review_id: 2_227_372_510,
        id: 1_709_082_321,
        path: 'test/baza/test_locks.rb',
        commit_id: 'a9f5f94cf28f29a64d5dd96d0ee23b4174572847',
        original_commit_id: 'e8c6f94274d14ed3cb26fe71467a9c3f229df59c',
        user: {
          login: 'test',
          id: 88_084_038
        },
        body: 'author comment',
        created_at: '2024-08-08T09:42:46Z',
        updated_at: '2024-08-08T09:42:46Z',
        reactions: {
          url: 'https://api.github.com/repos/zerocracy/baza/pulls/comments/1709082321/reactions',
          total_count: 1
        },
        start_line: 'null',
        original_start_line: 'null',
        start_side: 'null',
        line: 'null',
        original_line: 62,
        side: 'RIGHT',
        original_position: 25,
        in_reply_to_id: 1_709_082_318,
        position: 'null',
        subject_type: 'line'
      }
    ]
  end

  def issue_comment_reactions(_name, _comment)
    [
      {
        id: 248_923_574,
        user: {
          login: 'user',
          id: 8_086_956
        },
        content: 'heart'
      }
    ]
  end

  def pull_request_review_comment_reactions(_name, _comment)
    [
      {
        id: 248_923_574,
        user: {
          login: 'user',
          id: 8_086_956
        },
        content: 'heart'
      }
    ]
  end

  def check_runs_for_ref(repo, sha)
    data = {
      'zerocracy/baza' => {
        total_count: 7,
        check_runs: [
          {
            id: 28_907_016_501,
            name: 'make',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_603,
            name: 'copyrights',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_550,
            name: 'markdown-lint',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_483,
            name: 'pdd',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_433,
            name: 'rake',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_405,
            name: 'shellcheck',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_379,
            name: 'yamllint',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          }
        ]
      },
      'zerocracy/judges-action' => {
        total_count: 7,
        check_runs: [
          {
            id: 28_907_016_501,
            name: 'Codacy Static Code Analysis',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'codacy-production'
            }
          },
          {
            id: 28_906_596_603,
            name: 'copyrights',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_550,
            name: 'markdown-lint',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_483,
            name: 'pdd',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_433,
            name: 'rake',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_405,
            name: 'shellcheck',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          },
          {
            id: 28_906_596_379,
            name: 'yamllint',
            head_sha: sha,
            started_at: '2024-08-18T08:04:44Z',
            completed_at: '2024-08-18T08:20:17Z',
            app: {
              slug: 'github-actions'
            }
          }
        ]
      }
    }
    data.fetch(repo) do
      { total_count: 0, check_runs: [] }
    end
  end

  def workflow_run_job(_repo, job)
    [
      {
        id: 28_907_016_501,
        run_id: 10_438_531_072,
        name: 'make',
        started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 28_906_596_603,
        run_id: 10_438_531_073,
        name: 'copyrights',
        started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 28_906_596_550,
        run_id: 10_438_531_074,
        name: 'markdown-lint',
        started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 28_906_596_483,
        run_id: 10_438_531_075,
        name: 'pdd',
        started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 28_906_596_433,
        run_id: 10_438_531_076,
        name: 'rake',
        started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 28_906_596_405,
        run_id: 10_438_531_077,
        name: 'shellcheck',
        started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 28_906_596_379,
        run_id: 10_438_531_078,
        name: 'yamllint',
        started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      }
    ].find { |json| json[:id] == job } || {
      id: job,
      run_id: 1234,
      name: 'run job',
      started_at: '2024-08-18T08:04:44Z',
      completed_at: '2024-08-18T08:20:17Z'
    }
  end

  def workflow_run(repo, id)
    [
      {
        id: 10_438_531_072,
        event: 'pull_request',
        conclusion: 'success',
        name: 'make',
        started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 10_438_531_073,
        event: 'pull_request',
        conclusion: 'success',
        name: 'copyrights',
        started_at: '2024-08-18T08:04:44Z',
        run_started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 10_438_531_074,
        event: 'pull_request',
        conclusion: 'success',
        name: 'markdown-lint',
        started_at: '2024-08-18T08:04:44Z',
        run_started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 10_438_531_075,
        event: 'pull_request',
        conclusion: 'failure',
        name: 'pdd',
        started_at: '2024-08-18T08:04:44Z',
        run_started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 10_438_531_076,
        event: 'pull_request',
        conclusion: 'success',
        name: 'rake',
        started_at: '2024-08-18T08:04:44Z',
        run_started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 10_438_531_077,
        event: 'commit',
        conclusion: 'success',
        name: 'shellcheck',
        started_at: '2024-08-18T08:04:44Z',
        run_started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      },
      {
        id: 10_438_531_078,
        event: 'pull_request',
        conclusion: 'failure',
        name: 'yamllint',
        started_at: '2024-08-18T08:04:44Z',
        run_started_at: '2024-08-18T08:04:44Z',
        completed_at: '2024-08-18T08:20:17Z'
      }
    ].find { |json| json[:id] == id } || {
      id:,
      name: 'copyrights',
      head_branch: 'master',
      head_sha: '7d34c53e6743944dbf6fc729b1066bcbb3b18443',
      event: 'push',
      status: 'completed',
      conclusion: 'success',
      workflow_id: id,
      created_at: random_time,
      run_started_at: random_time,
      repository: repository(repo)
    }
  end

  def compare(_repo, _start, _end)
    {
      base_commit: {
        sha: '498464613c0b9',
        commit: {
          author: {
            name: 'Yegor Bugayenko', email: 'yegor256@gmail.com', date: Time.parse('2024-09-04 15:23:25 UTC')
          },
          committer: {
            name: 'Yegor Bugayenko', email: 'yegor256@gmail.com', date: Time.parse('2024-09-04 15:23:25 UTC')
          },
          message: 'Some text',
          tree: { sha: '51aee236ba884' },
          comment_count: 0,
          verification: { verified: false, reason: 'unsigned', signature: nil, payload: nil }
        },
        author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
        committer: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
        parents: [{ sha: '9763dab47b50a12f59c3630690ec2c0f6bdda0b3' }]
      },
      merge_base_commit: {
        sha: '8e4348746638595a7e',
        commit: {
          author: {
            name: 'Yegor Bugayenko', email: 'yegor256@gmail.com', date: Time.parse('2024-08-25 15:57:35 UTC')
          },
          committer: {
            name: 'Yegor Bugayenko', email: 'yegor256@gmail.com', date: Time.parse('2024-08-25 15:57:35 UTC')
          },
          message: 'Some text',
          tree: { sha: '7145fc122e70bf51e1d' },
          comment_count: 0,
          verification: { verified: true, reason: 'valid', signature: '', payload: '' }
        },
        author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
        committer: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
        parents: [
          { sha: '8c8278efedbd795e70' },
          { sha: '7dfd2e0186113f66f' }
        ]
      },
      status: 'diverged',
      ahead_by: 1,
      behind_by: 30,
      total_commits: 1,
      commits: [
        {
          sha: 'ee04386901692abb',
          commit: {
            author: {
              name: 'Yegor Bugayenko', email: 'yegor256@gmail.com', date: Time.parse('2024-08-25 15:57:35 UTC')
            },
            committer: {
              name: 'Yegor Bugayenko', email: 'yegor256@gmail.com', date: Time.parse('2024-08-25 15:57:35 UTC')
            },
            message: 'Some text',
            tree: { sha: '7a6124a500aed8c92' },
            comment_count: 0,
            verification: { verified: false, reason: 'unsigned', signature: nil, payload: nil }
          },
          author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          committer: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
          parents: [{ sha: '8e4348746638595a7e' }]
        }
      ],
      files: [
        {
          sha: '9e100c7246c0cc9', filename: 'file.txt', status: 'modified',
          additions: 1, deletions: 1, changes: 2,
          patch: '@@ -24,7 +24,7 @@ text ...'
        },
        {
          sha: 'f97818271059e5455', filename: 'file2.txt', status: 'modified',
          additions: 1, deletions: 1, changes: 2,
          patch: '@@ -25,7 +25,7 @@ text ...'
        },
        {
          sha: '5a957c57d090bfeccb', filename: 'file3.txt', status: 'modified',
          additions: 1, deletions: 1, changes: 2,
          patch: '@@ -27,7 +27,7 @@ text ...'
        }
      ]
    }
  end

  def tree(_repo, _tree_sha, _options = {})
    {
      sha: '492072971ad3c8644a191f62426bd3',
      tree: [
        {
          path: '.github',
          mode: '040000',
          type: 'tree',
          sha: '438682e07e45ccbf9ca58f294a'
        },
        {
          path: '.github/workflows',
          mode: '040000',
          type: 'tree',
          sha: 'dea8a01c236530cc92a63c5774'
        },
        {
          path: '.github/workflows/actionlint.yml',
          mode: '100644',
          type: 'blob',
          sha: 'ffed2deef2383d6f685489b289',
          size: 1671
        },
        {
          path: '.github/workflows/copyrights.yml',
          mode: '100644',
          type: 'blob',
          sha: 'ab8357cfd94e0628676aff34cd',
          size: 1293
        },
        {
          path: '.github/workflows/zerocracy.yml',
          mode: '100644',
          type: 'blob',
          sha: '5c224c7742e5ebeeb176b90605',
          size: 2005
        },
        {
          path: '.gitignore',
          mode: '100644',
          type: 'blob',
          sha: '9383e7111a173b44baa0692775',
          size: 27
        },
        {
          path: '.rubocop.yml',
          mode: '100644',
          type: 'blob',
          sha: 'cb9b62eb1979589daa18142008',
          size: 1963
        },
        {
          path: 'README.md',
          mode: '100644',
          type: 'blob',
          sha: '8011ad43c37edbaf1969417b94',
          size: 4877
        },
        {
          path: 'Rakefile',
          mode: '100644',
          type: 'blob',
          sha: 'a0ac9bf2643d9f5392e1119301',
          size: 1805
        }
      ],
      truncated: false
    }
  end

  def contributors(_repo, _anon = nil, _options = {})
    [
      {
        login: 'yegor256',
        id: 526_301,
        type: 'User',
        contributions: 500
      },
      {
        login: 'renovate[bot]',
        id: 29_139_614,
        type: 'Bot',
        contributions: 320
      },
      {
        login: 'user1',
        id: 2_476_362,
        type: 'User',
        contributions: 120
      },
      {
        login: 'rultor',
        id: 8_086_956,
        type: 'Bot',
        contributions: 87
      },
      {
        login: 'user2',
        id: 5_427_638,
        type: 'User',
        contributions: 49
      },
      {
        login: 'user3',
        id: 2_648_875,
        type: 'User',
        contributions: 10
      },
      {
        login: 'user4',
        id: 7_125_293,
        type: 'User',
        contributions: 1
      }
    ]
  end
end
