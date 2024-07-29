# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'loog'
require 'decoor'
require 'obk'
require 'octokit'
require 'verbose'
require 'faraday/http_cache'
require 'faraday/retry'
require_relative '../fbe'
require_relative 'faraday_middleware/quota'

def Fbe.octo(options: $options, global: $global, loog: $loog)
  raise 'The $global is not set' if global.nil?
  global[:octo] ||= begin
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
        loog.debug("The 'github_token' option was provided")
      end
      if token.nil?
        loog.warn('Accessing GitHub API without a token!')
      elsif token.empty?
        loog.warn('The GitHub API token is an empty string, won\'t use it')
      else
        o = Octokit::Client.new(access_token: token)
        loog.info("Accessing GitHub API with a token (#{token.length} chars, ending by #{token[-4..]})")
      end
      o.auto_paginate = true
      o.per_page = 100
      o.connection_options = {
        request: {
          open_timeout: 15,
          timeout: 15
        }
      }
      stack = Faraday::RackBuilder.new do |builder|
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
        builder.use(
          Fbe::FaradayMiddleware::Quota,
          logger: loog,
          github_api_pause: options.github_api_pause || 60
        )
        builder.use(Faraday::HttpCache, serializer: Marshal, shared_cache: false, logger: Loog::NULL)
        builder.use(Octokit::Response::RaiseError)
        builder.use(Faraday::Response::Logger, Loog::NULL)
        builder.adapter(Faraday.default_adapter)
      end
      o.middleware = stack
      o = Verbose.new(o, log: loog)
    else
      loog.debug('The connection to GitHub API is mocked')
      o = Fbe::FakeOctokit.new
    end
    decoor(o, loog:) do
      def off_quota
        left = @origin.rate_limit.remaining
        if left < 5
          @loog.info("To much GitHub API quota consumed already (remaining=#{left}), stopping")
          true
        else
          false
        end
      end

      def user_name_by_id(id)
        json = @origin.user(id)
        name = json[:login]
        @loog.debug("GitHub user ##{id} has a name: @#{name}")
        name
      end

      def repo_id_by_name(name)
        json = @origin.repository(name)
        id = json[:id]
        @loog.debug("GitHub repository #{name} has an ID: ##{id}")
        id
      end

      def repo_name_by_id(id)
        json = @origin.repository(id)
        name = json[:full_name]
        @loog.debug("GitHub repository ##{id} has a name: #{name}")
        name
      end
    end
  end
end

# Fake GitHub client, for tests.
class Fbe::FakeOctokit
  def random_time
    Time.now - rand(10_000)
  end

  def name_to_number(name)
    return name unless name.is_a?(String)
    name.chars.map(&:ord).inject(0, :+)
  end

  def rate_limit
    o = Object.new
    def o.remaining
      100
    end
    o
  end

  def repositories(_user = nil)
    [
      repository('yegor256/judges'),
      repository('yegor256/factbase')
    ]
  end

  def user(name)
    login = name
    login = name == 526_301 ? 'yegor256' : 'torvalds' if login.is_a?(Integer)
    {
      id: 444,
      login:,
      type: name == 29_139_614 ? 'Bot' : 'User'
    }
  end

  def repository_workflow_runs(repo, _opts = {})
    {
      total_count: 2,
      workflow_runs: [
        workflow_run(repo, 42),
        workflow_run(repo, 7)
      ]
    }
  end

  def workflow_run(repo, id)
    {
      id:,
      name: 'copyrights',
      head_branch: 'master',
      head_sha: '7d34c53e6743944dbf6fc729b1066bcbb3b18443',
      event: 'push',
      status: 'completed',
      conclusion: 'success',
      workflow_id: id,
      created_at: random_time,
      repository: repository(repo)
    }
  end

  def releases(_repo, _opts = {})
    [
      release('https://github...'),
      release('https://gith')
    ]
  end

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

  def repository(name)
    {
      id: name_to_number(name),
      full_name: name.is_a?(Integer) ? 'yegor256/test' : name,
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
      size: 470,
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
      archived: false,
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

  def commit_pulls(repo, _sha)
    [
      pull_request(repo, 42)
    ]
  end

  def pull_request(repo, number)
    {
      id: 42,
      number:,
      repo: {
        full_name: repo
      }
    }
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

  def search_issues(_query, _options = {})
    {
      items: [
        {
          number: 42,
          labels: [
            {
              name: 'bug'
            }
          ]
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
          size: 1,
          distinct_size: 0,
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
      }
    ]
  end
end
