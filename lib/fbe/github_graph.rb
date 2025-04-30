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
