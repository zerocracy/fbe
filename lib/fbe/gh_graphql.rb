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
require_relative 'github'

# Interface to GitHub GraphQL API.
#
# It is supposed to be used instead of GraphQL client, because it
# is pre-configured and enables additional fearues, such as retrying,
# logging, and caching.
#
# @param [Judges::Options] options The options available globally
# @param [Hash] global Hash of global options
# @param [Loog] loog Logging facility
def Fbe.gh_graphql(options: $options, global: $global, loog: $loog)
  global[:gh_graphql] ||=
    begin
      if options.testing.nil?
        g = Fbe::GitHub::GraphQL::Client.new(token: options.github_token || ENV.fetch('GITHUB_TOKEN', nil))
      else
        loog.debug('The connection to GitHub GraphQL API is mocked')
        g = Fbe::FakeGitHubGraphQLClient.new
      end
      decoor(g, loog:) do
        def resolved_converstations(owner, name, number)
          result = @origin.query(
            <<-GRAPHQL
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
          result.repository.pull_request.review_threads.to_h['nodes']
        end

        def total_commits(owner, name, branch)
          result = @origin.query(
            <<-GRAPHQL
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
      end
    end
end

# Fake GitHub GraphQL client, for tests.
class Fbe::FakeGitHubGraphQLClient
  def query(_query)
    {}
  end
end
