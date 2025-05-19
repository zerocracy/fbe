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
  # @return [Integer] The total number of commits in the branch
  # @example
  #   graph = Fbe::Graph.new(token: 'github_token')
  #   count = graph.total_commits('octocat', 'Hello-World', 'main')
  #   puts count #=> 42
  def total_commits(owner, name, branch)
    result = query(
      <<~GRAPHQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
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
        }
      GRAPHQL
    )
    result.repository.ref.target.history.total_count
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

  # Fake GitHub GraphQL client, for tests.
  class Fake
    def query(_query)
      {}
    end

    def resolved_conversations(owner, name, _number)
      data = {
        zerocracy_baza: [
          conversation('PRRT_kwDOK2_4A85BHZAR')
        ]
      }
      data[:"#{owner}_#{name}"] || []
    end

    def total_issues_and_pulls(_owner, _name)
      {
        'issues' => 23,
        'pulls' => 19
      }
    end

    def total_commits(_owner, _name, _branch)
      1484
    end

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

    private

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
