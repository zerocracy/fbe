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
require_relative 'middleware'
require_relative 'middleware/quota'
require_relative 'middleware/logging_formatter'

# Interface to GitHub API.
#
# It is supposed to be used instead of Octokit client, because it
# is pre-configured and enables additional fearues, such as retrying,
# logging, and caching.
#
# @param [Judges::Options] options The options available globally
# @param [Hash] global Hash of global options
# @param [Loog] loog Logging facility
def Fbe.octo(options: $options, global: $global, loog: $loog)
  raise 'The $global is not set' if global.nil?
  global[:octo] ||=
    begin
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
            builder.use(Fbe::Middleware::Quota, loog:, pause: options.github_api_pause || 60)
            builder.use(Faraday::HttpCache, serializer: Marshal, shared_cache: false, logger: Loog::NULL)
            builder.use(Octokit::Response::RaiseError)
            builder.use(
              Faraday::Response::Logger,
              loog,
              {
                formatter: Fbe::Middleware::LoggingFormatter,
                log_only_errors: true,
                headers: true,
                bodies: true,
                errors: false
              }
            )
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

  def commit_pulls(repo, _sha)
    [
      pull_request(repo, 42)
    ]
  end

  def list_issues(repo, _options = {})
    [
      issue(repo, 42),
      issue(repo, 43)
    ]
  end

  def issue(repo, number)
    {
      id: 42,
      number:,
      repo: {
        full_name: repo
      },
      pull_request: {
        merged_at: nil
      }
    }
  end

  def pull_request(repo, number)
    {
      id: 42,
      number:,
      repo: {
        full_name: repo
      },
      additions: 12,
      deletions: 5,
      changed_files: 3
    }
  end

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
            ]
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
          ref_type: 'tag',
          ref: 'foo',
          pull_request: {
            url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
            id: 1_990_323_142,
            node_id: 'PR_kwDOL6GCO852oevG',
            number: 172,
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
              label: 'zerocracy:master',
              ref: 'master',
              user: {
                login: 'zerocracy',
                id: 24_234_201
              },
              repo: {
                id: repo,
                node_id: 'R_kgDOK2_4Aw',
                name: 'baza',
                full_name: 'zerocracy/baza',
                private: false
              }
            },
            head: {
              ref: 'zerocracy/baza',
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
          ref_type: 'tag',
          ref: 'foo',
          pull_request: {
            url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
            id: 1_990_323_142,
            node_id: 'PR_kwDOL6GCO852oevG',
            number: 172,
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
              label: 'zerocracy:master',
              ref: 'master',
              user: {
                login: 'zerocracy',
                id: 24_234_201
              },
              repo: {
                id: repo,
                node_id: 'R_kgDOK2_4Aw',
                name: 'judges-action',
                full_name: 'zerocracy/judges-action',
                private: false
              }
            },
            head: {
              ref: 'zerocracy/judges-action',
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
        }
      }
    ]
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
    ].select { |json| json[:id] == job }.first || {
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
    ].select { |json| json[:id] == id }.first || {
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
