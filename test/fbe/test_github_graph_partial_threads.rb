# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/github_graph'
require_relative '../test__helper'

class TestGithubGraphPartialThreads < Fbe::Test
  def test_returns_no_threads_when_the_pull_is_missing
    assert_empty(resolve([{ 'repository' => { 'pullRequest' => nil } }]))
  end

  def test_returns_a_thread_without_comments_unchanged
    thread = { 'id' => 'thread-one', 'isResolved' => true }
    assert_equal([thread], resolve([thread_page(thread)]))
  end

  def test_keeps_known_comments_when_the_next_node_is_missing
    result = resolve([thread_page(paginated_thread), { 'node' => nil }])
    assert_equal([{ 'id' => 'comment-one' }], result.first.dig('comments', 'nodes'))
  end

  def test_accepts_a_comment_page_without_nodes
    page = { 'node' => { 'comments' => { 'pageInfo' => { 'hasNextPage' => false } } } }
    result = resolve([thread_page(paginated_thread), page])
    assert_equal([{ 'id' => 'comment-one' }], result.first.dig('comments', 'nodes'))
  end

  def test_keeps_comments_and_stops_when_the_page_info_is_missing
    page = { 'node' => { 'comments' => { 'nodes' => [{ 'id' => 'comment-two' }] } } }
    result = resolve([thread_page(paginated_thread), page])
    assert_equal(%w[comment-one comment-two], result.first.dig('comments', 'nodes').map { |comment| comment['id'] })
  end

  private

  def resolve(pages)
    graph = Fbe::Graph.new(token: 'synthetic-token')
    response = ->(_query) { pages.shift || flunk('an unexpected extra page was requested') }
    result = graph.stub(:query, response) { graph.resolved_conversations('foo', 'bar', 42) }
    assert_empty(pages, 'all expected pages must be requested')
    result
  end

  def thread_page(thread)
    {
      'repository' => {
        'pullRequest' => {
          'reviewThreads' => {
            'nodes' => [thread], 'pageInfo' => { 'hasNextPage' => false }
          }
        }
      }
    }
  end

  def paginated_thread
    {
      'id' => 'thread-one', 'isResolved' => true,
      'comments' => {
        'nodes' => [{ 'id' => 'comment-one' }],
        'pageInfo' => { 'hasNextPage' => true, 'endCursor' => 'next-comments' }
      }
    }
  end
end
