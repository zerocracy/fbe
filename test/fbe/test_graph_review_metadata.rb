# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/github_graph'
require_relative '../test__helper'

# The review metadata needed to classify submitted reviews.
class TestGraphReviewMetadata < Fbe::Test
  def test_selects_and_preserves_review_authors_and_states
    WebMock.disable_net_connect!
    graph = Fbe::Graph.new(token: 'fake')
    authors = [
      { 'login' => 'reviewer', '__typename' => 'User' },
      { 'login' => 'review-bot', '__typename' => 'Bot' },
      nil
    ]
    states = %w[APPROVED COMMENTED DISMISSED]
    request = nil
    graph.define_singleton_method(:query) do |query|
      request = query
      {
        'repository' => {
          'pr_2' => {
            'id' => 'PR_2', 'number' => 2,
            'reviews' => {
              'nodes' => authors.each_with_index.map do |author, index|
                {
                  'id' => "review-#{index}", 'submittedAt' => '2025-10-02T12:58:42Z',
                  'author' => author, 'state' => states[index]
                }
              end,
              'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
            }
          }
        }
      }
    end
    reviews = graph.pull_request_reviews('foo', 'bar', pulls: [[2, nil]]).first['reviews']
    assert_equal(authors, reviews.map { _1['author'] })
    assert_equal(states, reviews.map { _1['state'] })
    assert_equal(%w[review-0 review-1 review-2], reviews.map { _1['id'] })
    assert_equal(Array.new(3, Time.parse('2025-10-02T12:58:42Z')), reviews.map { _1['submitted_at'] })
    selection =
      GraphQL.parse(request).definitions.first.selections.first.selections.first.selections
        .find { _1.name == 'reviews' }.selections.find { _1.name == 'nodes' }
    assert_includes(selection.selections.map(&:name), 'state')
    assert_equal(%w[login __typename], selection.selections.find { _1.name == 'author' }.selections.map(&:name))
  end

  def test_fake_reviews_expose_the_same_metadata
    WebMock.disable_net_connect!
    reviews = Fbe::Graph::Fake.new.pull_request_reviews('foo', 'bar', pulls: [[2, nil]]).flat_map { _1['reviews'] }
    refute_empty(reviews)
    reviews.each do |review|
      assert_includes(%w[APPROVED CHANGES_REQUESTED COMMENTED DISMISSED], review['state'])
      assert(review.key?('author'), 'the author key must exist even for a deleted account')
      next if review['author'].nil?
      assert_kind_of(String, review['author']['login'])
      assert_includes(%w[User Bot], review['author']['__typename'])
    end
  end
end
