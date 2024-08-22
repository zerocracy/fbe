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
require 'graphql/client'
require 'graphql/client/http'

# Interface to GitHub GraphQL API.
#
# @param [Judges::Options] options The options available globally
# @param [Hash] global Hash of global options
# @param [Loog] loog Logging facility
def Fbe.github_graph(options: $options, global: $global, loog: $loog)
  global[:github_graph] ||=
    if options.testing.nil?
      Fbe::Graph.new(token: options.github_token || ENV.fetch('GITHUB_TOKEN', nil))
    else
      loog.debug('The connection to GitHub GraphQL API is mocked')
      Fbe::Graph::Fake.new
    end
end

# The GitHub GraphQL client
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
    result&.to_h&.dig('repository', 'pullRequest', 'reviewThreads', 'nodes') || []
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
