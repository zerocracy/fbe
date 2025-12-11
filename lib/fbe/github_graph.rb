# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'graphql/client'
require 'graphql/client/http'
require 'loog'
require_relative '../fbe'

# Creates an instance of {Fbe::Graph}.
#
# @param [Judges::Options] options The options available globally
# @param [Hash] global Hash of global options
# @param [Loog] loog Logging facility
# @return [Fbe::Graph] The instance of the class
def Fbe.github_graph(options: $options, global: $global, loog: $loog)
  global[:github_graph] ||=
    if options.testing.nil?
      Fbe::Graph.new(token: options.github_token || ENV.fetch('GITHUB_TOKEN', nil))
    else
      loog.debug('The connection to GitHub GraphQL API is mocked')
      Fbe::Graph::Fake.new
    end
end

# A client to GitHub GraphQL.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Graph
  def initialize(token:, host: 'api.github.com')
    @token = token
    @host = host
  end

  # Executes a GraphQL query against the GitHub API.
  #
  # @param [String] qry The GraphQL query to execute
  # @return [GraphQL::Client::Response] The query result data
  # @example
  #   graph = Fbe::Graph.new(token: 'github_token')
  #   result = graph.query('{viewer {login}}')
  #   puts result.viewer.login #=> "octocat"
  def query(qry)
    result = client.query(client.parse(qry))
    result.data
  end

  # Retrieves resolved conversation threads from a pull request.
  #
  # @param [String] owner The repository owner (username or organization)
  # @param [String] name The repository name
  # @param [Integer] number The pull request number
  # @return [Array<Hash>] An array of resolved conversation threads with their comments
  # @example
  #   graph = Fbe::Graph.new(token: 'github_token')
  #   threads = graph.resolved_conversations('octocat', 'Hello-World', 42)
  #   threads.first['comments']['nodes'].first['body'] #=> "Great work!"
  def resolved_conversations(owner, name, number)
    result = query(
      <<~GRAPHQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
            pullRequest(number: #{number}) {
              reviewThreads(first: 100) {
                nodes {
                  id
                  isResolved
                  comments(first: 100) {
                    nodes {
                      id
                      body
                      author {
                        login
                      }
                      createdAt
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    )
    result&.to_h&.dig('repository', 'pullRequest', 'reviewThreads', 'nodes')&.select do |thread|
      thread['isResolved']
    end || []
  end

  # Gets the total number of commits in a branch.
  #
  # @param [String] owner The repository owner (username or organization)
  # @param [String] name The repository name
  # @param [String] branch The branch name (e.g., "master" or "main")
  # @param [Array<Array<String, String, String>>] repos List of owner, name, branch
  # @return [Integer, Array<Hash>] The total number of commits in the branch or array with hash
  # @example
  #   graph = Fbe::Graph.new(token: 'github_token')
  #   count = graph.total_commits('octocat', 'Hello-World', 'main')
  #   puts count #=> 42
  # @example
  #   result = Fbe.github_graph.total_commits(
  #     repos: [
  #       ['zerocracy', 'fbe', 'master'],
  #       ['zerocracy', 'judges-action', 'master']
  #     ]
  #   )
  #   puts result #=>
  #   [{"owner"=>"zerocracy", "name"=>"fbe", "branch"=>"master", "total_commits"=>754},
  #    {"owner"=>"zerocracy", "name"=>"judges-action", "branch"=>"master", "total_commits"=>2251}]
  def total_commits(owner = nil, name = nil, branch = nil, repos: nil)
    raise 'Need owner, name and branch or repos' if owner.nil? && name.nil? && branch.nil? && repos.nil?
    raise 'Owner, name and branch is required' if (owner.nil? || name.nil? || branch.nil?) && repos.nil?
    raise 'Repos list cannot be empty' if owner.nil? && name.nil? && branch.nil? && repos&.empty?
    raise 'Need only owner, name and branch or repos' if (!owner.nil? || !name.nil? || !branch.nil?) && !repos.nil?
    repos ||= [[owner, name, branch]]
    requests =
      repos.each_with_index.map do |(owner, name, branch), i|
        <<~GRAPHQL
          repo_#{i}: repository(owner: "#{owner}", name: "#{name}") {
            ref(qualifiedName: "#{branch}") {
              target {
                ... on Commit {
                  history {
                    totalCount
                  }
                }
              }
            }
          }
        GRAPHQL
      end
    result = query("{\n#{requests.join("\n")}\n}")
    if owner && name && branch
      ref = result.repo_0&.ref
      raise "Repository '#{owner}/#{name}' or branch '#{branch}' not found" unless ref&.target&.history
      ref.target.history.total_count
    else
      repos.each_with_index.map do |(owner, name, branch), i|
        ref = result.send(:"repo_#{i}")&.ref
        raise "Repository '#{owner}/#{name}' or branch '#{branch}' not found" unless ref&.target&.history
        {
          'owner' => owner,
          'name' => name,
          'branch' => branch,
          'total_commits' => ref.target.history.total_count
        }
      end
    end
  end

  # Gets the total number of issues and pull requests in a repository.
  #
  # @param [String] owner The repository owner (username or organization)
  # @param [String] name The repository name
  # @return [Hash] A hash with 'issues' and 'pulls' counts
  # @example
  #   graph = Fbe::Graph.new(token: 'github_token')
  #   counts = graph.total_issues_and_pulls('octocat', 'Hello-World')
  #   puts counts #=> {"issues"=>42, "pulls"=>17}
  def total_issues_and_pulls(owner, name)
    result = query(
      <<~GRAPHQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
            issues {
              totalCount
            }
            pullRequests {
              totalCount
            }
          }
        }
      GRAPHQL
    ).to_h
    {
      'issues' => result.dig('repository', 'issues', 'totalCount') || 0,
      'pulls' => result.dig('repository', 'pullRequests', 'totalCount') || 0
    }
  end

  # Get info about issue type event
  #
  # @param [String] node_id ID of the event object
  # @return [Hash] A hash with issue type event
  def issue_type_event(node_id)
    result = query(
      <<~GRAPHQL
        {
          node(id: "#{node_id}") {
            __typename
            ... on IssueTypeAddedEvent {
              id
              createdAt
              issueType { ...IssueTypeFragment }
              actor { ...ActorFragment }
            }
            ... on IssueTypeChangedEvent {
              id
              createdAt
              issueType { ...IssueTypeFragment }
              prevIssueType { ...IssueTypeFragment }
              actor { ...ActorFragment }
            }
            ... on IssueTypeRemovedEvent {
              id
              createdAt
              issueType { ...IssueTypeFragment }
              actor { ...ActorFragment }
            }
          }
        }
        fragment ActorFragment on Actor {
          __typename
          login
          ... on User { databaseId name email }
          ... on Bot { databaseId }
          ... on EnterpriseUserAccount { user { databaseId name email } }
          ... on Mannequin { claimant { databaseId name email } }
        }
        fragment IssueTypeFragment on IssueType {
          id
          name
          description
        }
      GRAPHQL
    ).to_h
    return unless result['node']
    type = result.dig('node', '__typename')
    prev_issue_type =
      if type == 'IssueTypeChangedEvent'
        {
          'id' => result.dig('node', 'prevIssueType', 'id'),
          'name' => result.dig('node', 'prevIssueType', 'name'),
          'description' => result.dig('node', 'prevIssueType', 'description')
        }
      end
    {
      'type' => type,
      'created_at' => Time.parse(result.dig('node', 'createdAt')),
      'issue_type' => {
        'id' => result.dig('node', 'issueType', 'id'),
        'name' => result.dig('node', 'issueType', 'name'),
        'description' => result.dig('node', 'issueType', 'description')
      },
      'prev_issue_type' => prev_issue_type,
      'actor' => {
        'login' => result.dig('node', 'actor', 'login'),
        'type' => result.dig('node', 'actor', '__typename'),
        'id' => result.dig('node', 'actor', 'databaseId') ||
          result.dig('node', 'actor', 'user', 'databaseId') ||
          result.dig('node', 'actor', 'claimant', 'databaseId'),
        'name' => result.dig('node', 'actor', 'name') ||
          result.dig('node', 'actor', 'user', 'name') ||
          result.dig('node', 'actor', 'claimant', 'name'),
        'email' => result.dig('node', 'actor', 'email') ||
          result.dig('node', 'actor', 'user', 'email') ||
          result.dig('node', 'actor', 'claimant', 'email')
      }
    }
  end

  # Get pulls id and number with review from since
  #
  # @param [String] owner The repository owner (username or organization)
  # @param [String] name The repository name
  # @param [Time] since The datetime from
  # @param [String, nil] cursor Github cursor for next page
  # @return [Hash] A hash with pulls
  # @example
  #   graph = Fbe::Graph.new(token: 'github_token')
  #   cursor = nil
  #   pulls = []
  #   loop do
  #     json = graph.pull_requests_with_reviews(
  #       'zerocracy', 'judges-action', Time.parse('2025-08-01T18:00:00Z'), cursor:
  #     )
  #     json['pulls_with_reviews'].each do |p|
  #       pulls.push(p['number'])
  #     end
  #     break unless json['has_next_page']
  #     cursor = json['next_cursor']
  #   end
  def pull_requests_with_reviews(owner, name, since, cursor: nil)
    result = query(
      <<~GRAPHQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
            pullRequests(first: 100, after: "#{cursor}") {
              nodes {
                id
                number
                timelineItems(first: 1, itemTypes: [PULL_REQUEST_REVIEW], since: "#{since.utc.iso8601}") {
                  nodes {
                    ... on PullRequestReview { id }
                  }
                }
              }
              pageInfo {
                hasNextPage
                endCursor
              }
            }
          }
        }
      GRAPHQL
    ).to_h
    {
      'pulls_with_reviews' => result
        .dig('repository', 'pullRequests', 'nodes')
        .reject { _1.dig('timelineItems', 'nodes').empty? }
        .map do |pull|
          {
            'id' => pull['id'],
            'number' => pull['number']
          }
        end,
      'has_next_page' => result.dig('repository', 'pullRequests', 'pageInfo', 'hasNextPage'),
      'next_cursor' => result.dig('repository', 'pullRequests', 'pageInfo', 'endCursor')
    }
  end

  # Get reviews by pull numbers
  #
  # @param [String] owner The repository owner (username or organization)
  # @param [String] name The repository name
  # @param [Array<Array<Integer, (String, nil)>>] pulls Array of pull number and Github cursor
  # @return [Hash] A hash with reviews
  # @example
  #   graph = Fbe::Graph.new(token: 'github_token')
  #   queue = [[1108, nil], [1105, nil]]
  #   until queue.empty?
  #     pulls = graph.pull_request_reviews('zerocracy', 'judges-action', pulls: queue.shift(10))
  #     pulls.each do |pull|
  #       puts pull['id'], pull['number']
  #       pull['reviews'].each do |r|
  #         puts r['id'], r['submitted_at']
  #       end
  #     end
  #     pulls.select { _1['reviews_has_next_page'] }.each do |p|
  #       queue.push([p['number'], p['reviews_next_cursor']])
  #     end
  #   end
  def pull_request_reviews(owner, name, pulls: [])
    requests =
      pulls.map do |number, cursor|
        <<~GRAPHQL
          pr_#{number}: pullRequest(number: #{number}) {
            id
            number
            reviews(first: 100, after: "#{cursor}") {
              nodes {
                id
                submittedAt
              }
              pageInfo {
                hasNextPage
                endCursor
              }
            }
          }
        GRAPHQL
      end
    result = query(
      <<~GRAPHQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
            #{requests.join("\n")}
          }
        }
      GRAPHQL
    ).to_h
    result['repository'].map do |_k, v|
      {
        'id' => v['id'],
        'number' => v['number'],
        'reviews' => v.dig('reviews', 'nodes').map do |r|
          {
            'id' => r['id'],
            'submitted_at' => Time.parse(r['submittedAt'])
          }
        end,
        'reviews_has_next_page' => v.dig('reviews', 'pageInfo', 'hasNextPage'),
        'reviews_next_cursor' => v.dig('reviews', 'pageInfo', 'endCursor')
      }
    end
  end

  # Get total commits pushed to default branch
  #
  # @param [String] owner The repository owner (username or organization)
  # @param [String] name The repository name
  # @param [Time] since The datetime from
  # @return [Hash] A hash with total commits and hocs
  def total_commits_pushed(owner, name, since)
    # @todo #1223:60min Missing pagination could cause performance issues or API failures. You need add
    # pagination for commit history, for more info see
    # https://github.com/zerocracy/fbe/pull/366#discussion_r2610751758
    result = query(
      <<~GRAPHQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
            defaultBranchRef {
              target {
                ... on Commit {
                  history(since: "#{since.utc.iso8601}") {
                    totalCount
                    nodes {
                      oid
                      parents {
                        totalCount
                      }
                      additions
                      deletions
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    ).to_h
    commits = result.dig('repository', 'defaultBranchRef', 'target', 'history', 'nodes')
    {
      'commits' => result.dig('repository', 'defaultBranchRef', 'target', 'history', 'totalCount') || 0,
      'hoc' => commits.nil? ? 0 : commits.sum { (_1['additions'] || 0) + (_1['deletions'] || 0) }
    }
  end

  private

  # Creates or returns a cached GraphQL client instance.
  #
  # @return [GraphQL::Client] A configured GraphQL client for GitHub
  def client
    @client ||=
      begin
        http = HTTP.new(@token, @host)
        schema = GraphQL::Client.load_schema(http)
        c = GraphQL::Client.new(schema:, execute: http)
        c.allow_dynamic_queries = true
        c
      end
  end

  # HTTP transport class for GraphQL client to communicate with GitHub API
  #
  # This class extends GraphQL::Client::HTTP to handle GitHub-specific
  # authentication and endpoints.
  class HTTP < GraphQL::Client::HTTP
    # Initializes a new HTTP transport with GitHub authentication.
    #
    # @param [String] token GitHub API token for authentication
    # @param [String] host GitHub API host (default: 'api.github.com')
    def initialize(token, host)
      @token = token
      super("https://#{host}/graphql")
    end

    # Provides headers for GraphQL requests including authentication.
    #
    # @param [Object] _context The GraphQL request context (unused)
    # @return [Hash] Headers for the request
    def headers(_context)
      { Authorization: "Bearer #{@token}" }
    end
  end

  # Fake GitHub GraphQL client for testing.
  #
  # This class mocks the GraphQL client interface and returns predictable
  # test data without making actual API calls. It's used when the application
  # is in testing mode.
  #
  # @example Using the fake client in tests
  #   fake = Fbe::Graph::Fake.new
  #   result = fake.total_commits('owner', 'repo', 'main')
  #   # => 1484 (always returns the same value)
  class Fake
    # Executes a GraphQL query (mock implementation).
    #
    # @param [String] _query The GraphQL query (ignored)
    # @return [Hash] Empty hash
    def query(_query)
      {}
    end

    # Returns mock resolved conversation threads.
    #
    # @param [String] owner Repository owner
    # @param [String] name Repository name
    # @param [Integer] _number Pull request number (ignored)
    # @return [Array<Hash>] Array of conversation threads
    # @example
    #   fake.resolved_conversations('zerocracy', 'baza', 42)
    #   # => [conversation data for zerocracy_baza]
    def resolved_conversations(owner, name, _number)
      data = {
        zerocracy_baza: [
          conversation('PRRT_kwDOK2_4A85BHZAR')
        ]
      }
      data[:"#{owner}_#{name}"] || []
    end

    # Returns mock issue and pull request counts.
    #
    # @param [String] _owner Repository owner (ignored)
    # @param [String] _name Repository name (ignored)
    # @return [Hash] Hash with 'issues' and 'pulls' counts
    # @example
    #   fake.total_issues_and_pulls('owner', 'repo')
    #   # => {"issues"=>23, "pulls"=>19}
    def total_issues_and_pulls(_owner, _name)
      {
        'issues' => 23,
        'pulls' => 19
      }
    end

    # Returns mock total commit count.
    #
    # @param [String] owner Repository owner
    # @param [String] name Repository name
    # @param [String] branch Branch name
    # @param [Array<Array<String, String, String>>] repos List of owner, name, branch
    # @return [Integer, Array<Hash>] Returns 1484 for single repo or array of hashes
    def total_commits(owner = nil, name = nil, branch = nil, repos: nil)
      raise 'Need owner, name and branch or repos' if owner.nil? && name.nil? && branch.nil? && repos.nil?
      raise 'Owner, name and branch is required' if (owner.nil? || name.nil? || branch.nil?) && repos.nil?
      raise 'Repos list cannot be empty' if owner.nil? && name.nil? && branch.nil? && repos&.empty?
      raise 'Need only owner, name and branch or repos' if (!owner.nil? || !name.nil? || !branch.nil?) && !repos.nil?
      if owner && name && branch
        1484
      else
        repos.each_with_index.map do |(owner, name, branch), _i|
          {
            'owner' => owner,
            'name' => name,
            'branch' => branch,
            'total_commits' => 1484
          }
        end
      end
    end

    # Returns mock issue type event data.
    #
    # @param [String] node_id The event node ID
    # @return [Hash, nil] Event data for known IDs, nil otherwise
    # @example
    #   fake.issue_type_event('ITAE_examplevq862Ga8lzwAAAAQZanzv')
    #   # => {'type'=>'IssueTypeAddedEvent', ...}
    def issue_type_event(node_id)
      case node_id
      when 'ITAE_examplevq862Ga8lzwAAAAQZanzv'
        {
          'type' => 'IssueTypeAddedEvent',
          'created_at' => Time.parse('2025-05-11 18:17:16 UTC'),
          'issue_type' => {
            'id' => 'IT_exampleQls4BmRE0',
            'name' => 'Bug',
            'description' => 'An unexpected problem or behavior'
          },
          'prev_issue_type' => nil,
          'actor' => {
            'login' => 'yegor256',
            'type' => 'User',
            'id' => 526_301,
            'name' => 'Yegor',
            'email' => 'example@gmail.com'
          }
        }
      when 'ITCE_examplevq862Ga8lzwAAAAQZbq9S'
        {
          'type' => 'IssueTypeChangedEvent',
          'created_at' => Time.parse('2025-05-11 20:23:13 UTC'),
          'issue_type' => {
            'id' => 'IT_kwDODJdQls4BmREz',
            'name' => 'Task',
            'description' => 'A specific piece of work'
          },
          'prev_issue_type' => {
            'id' => 'IT_kwDODJdQls4BmRE0',
            'name' => 'Bug',
            'description' => 'An unexpected problem or behavior'
          },
          'actor' => {
            'login' => 'yegor256',
            'type' => 'User',
            'id' => 526_301,
            'name' => 'Yegor',
            'email' => 'example@gmail.com'
          }
        }
      when 'ITRE_examplevq862Ga8lzwAAAAQcqceV'
        {
          'type' => 'IssueTypeRemovedEvent',
          'created_at' => Time.parse('2025-05-11 22:09:42 UTC'),
          'issue_type' => {
            'id' => 'IT_kwDODJdQls4BmRE1',
            'name' => 'Feature',
            'description' => 'A request, idea, or new functionality'
          },
          'prev_issue_type' => nil,
          'actor' => {
            'login' => 'yegor256',
            'type' => 'User',
            'id' => 526_301,
            'name' => 'Yegor',
            'email' => 'example@gmail.com'
          }
        }
      end
    end

    def pull_requests_with_reviews(_owner, _name, _since, **)
      {
        'pulls_with_reviews' => [
          { 'id' => 'PR_kwDOL6J6Ss6iprCx', 'number' => 2 },
          { 'id' => 'PR_kwDOL6J6Ss6rhJ7T', 'number' => 5 },
          { 'id' => 'PR_kwDOL6J6Ss6r13fG', 'number' => 21 }
        ],
        'has_next_page' => false,
        'next_cursor' => 'Y3Vyc29yOnYyOpHOdh_xUw=='
      }
    end

    def pull_request_reviews(_owner, _name, **)
      [
        {
          'id' => 'PR_kwDOL6J6Ss6iprCx',
          'number' => 2,
          'reviews' => [
            { 'id' => 'PRR_kwDOL6J6Ss647NCl', 'submitted_at' => Time.parse('2025-10-02 12:58:42 UTC') },
            { 'id' => 'PRR_kwDOL6J6Ss647NC8', 'submitted_at' => Time.parse('2025-10-02 15:58:42 UTC') }
          ],
          'reviews_has_next_page' => false,
          'reviews_next_cursor' => 'yc29yOnYyO1'
        },
        {
          'id' => 'PR_kwDOL6J6Ss6rhJ7T',
          'number' => 5,
          'reviews' => [{ 'id' => 'PRR_kwDOL6J6Ss64_mnn', 'submitted_at' => Time.parse('2025-10-03 15:58:42 UTC') }],
          'reviews_has_next_page' => false,
          'reviews_next_cursor' => 'yc29yOnYyO2'
        },
        {
          'id' => 'PR_kwDOL6J6Ss6r13fG',
          'number' => 21,
          'reviews' => [{ 'id' => 'PRR_kwDOL6J6Ss65AbIA', 'submitted_at' => Time.parse('2025-10-04 15:58:42 UTC') }],
          'reviews_has_next_page' => false,
          'reviews_next_cursor' => 'yc29yOnYyO3'
        }
      ]
    end

    def total_commits_pushed(_owner, _name, _since)
      {
        'commits' => 29,
        'hoc' => 1857
      }
    end

    private

    # Generates mock conversation thread data.
    #
    # @param [String] id The conversation thread ID
    # @return [Hash] Mock conversation data with comments
    def conversation(id)
      {
        'id' => id,
        'isResolved' => true,
        'comments' => {
          'nodes' => [
            {
              'id' => 'PRRC_kwDOK2_4A85l3obO',
              'body' => 'first message',
              'author' => { '__typename' => 'User', 'login' => 'reviewer' },
              'createdAt' => '2024-08-08T09:41:46Z'
            },
            {
              'id' => 'PRRC_kwDOK2_4A85l3yTp',
              'body' => 'second message',
              'author' => { '__typename' => 'User', 'login' => 'programmer' },
              'createdAt' => '2024-08-08T10:01:55Z'
            }
          ]
        }
      }
    end
  end
end
