# frozen_string_literal: true

require_relative 'lib/fbe/github_graph'

graph = Fbe::Graph.new(token: 'fake')

# Stub query to simulate GitHub API response without 'repository' key
# (happens on permission errors, repo renames, or GraphQL partial failures)
def graph.query(_gql)
  { 'errors' => [{ 'message' => 'Could not resolve to a Repository' }] }
end

begin
  result = graph.pull_requests_with_reviews('zerocracy', 'judges-action', Time.now - 86400)
  puts "No error — bug NOT reproduced. Result: #{result.inspect}"
rescue NoMethodError => e
  puts "REPRODUCED: #{e.class}: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end
