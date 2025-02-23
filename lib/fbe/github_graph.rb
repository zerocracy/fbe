# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'graphql/client'
require 'graphql/client/http'
require 'loog'

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
    http = HTTP.new(token, host)
    @client = GraphQL::Client.new(schema: GraphQL::Client.load_schema(http), execute: http)
    @client.allow_dynamic_queries = true
  end

  def query(query_string)
    result = @client.query(@client.parse(query_string))
    result.data
  end

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

  # The HTTP class
  class HTTP < GraphQL::Client::HTTP
    def initialize(token, host)
      @token = token
      super("https://#{host}/graphql")
    end

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
