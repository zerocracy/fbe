# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/unmask_repos'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestUnmaskRepos < Fbe::Test
  def test_simple_use
    opts = Judges::Options.new(
      {
        'testing' => true,
        'repositories' => 'yegor256/tacit,zerocracy/*,-zerocracy/judges-action,zerocracy/datum'
      }
    )
    list = Fbe.unmask_repos(options: opts, global: {}, loog: Loog::NULL)
    assert_predicate(list.size, :positive?)
    refute_includes(list, 'zerocracy/datum')
  end

  def test_iterates_them
    opts = Judges::Options.new({ 'testing' => true, 'repositories' => 'yegor256/tacit,zerocracy/*' })
    list = []
    Fbe.unmask_repos(options: opts, global: {}, loog: Loog::NULL) do |n|
      list << n
    end
    assert_predicate(list.size, :positive?)
  end

  def test_fails_on_broken_names
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(status: 404)
    options = Judges::Options.new({ 'repositories' => 'foo/bar' })
    assert_raises(StandardError) { Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL).each.to_a }
  end

  def test_finds_case_insensitive
    opts = Judges::Options.new({ 'testing' => true, 'repositories' => 'Yegor256/*' })
    list = Fbe.unmask_repos(options: opts, global: {}, loog: Loog::NULL)
    assert_equal(2, list.size)
  end

  def test_deduplicates_repos_matched_by_overlapping_masks
    opts = Judges::Options.new({ 'testing' => true, 'repositories' => 'yegor256/factbase,Yegor256/*' })
    list = Fbe.unmask_repos(options: opts, global: {}, loog: Loog::NULL)
    assert_equal(list.uniq.size, list.size, "duplicates found in #{list.inspect}")
    assert_includes(list, 'yegor256/factbase')
  end

  def test_mask_to_regex_treats_dot_as_literal
    re = Fbe.mask_to_regex('zold-io/blog.zold.io')
    assert_match(re, 'zold-io/blog.zold.io')
    refute_match(re, 'zold-io/blogXzoldYio')
  end

  def test_mask_to_regex_escapes_other_metacharacters
    re = Fbe.mask_to_regex('foo/bar+baz')
    assert_match(re, 'foo/bar+baz')
    refute_match(re, 'foo/barbaz')
    refute_match(re, 'foo/barrrbaz')
  end

  def test_mask_to_regex_still_expands_wildcard
    re = Fbe.mask_to_regex('zold-io/blog.zold.*')
    assert_match(re, 'zold-io/blog.zold.io')
    assert_match(re, 'zold-io/blog.zold.org')
    refute_match(re, 'zold-io/blogXzoldYio')
  end

  def test_mask_to_regex_exact_match
    re = Fbe.mask_to_regex('zerocracy/judges-action')
    assert_match(re, 'zerocracy/judges-action')
  end

  def test_mask_to_regex_prefix_collision
    re = Fbe.mask_to_regex('zerocracy/judges-action')
    refute_match(re, 'zerocracy/judges-actions')
    refute_match(re, 'zerocracy/judges-action-old')
  end

  def test_mask_to_regex_wildcard
    re = Fbe.mask_to_regex('zerocracy/*')
    assert_match(re, 'zerocracy/fbe')
    assert_match(re, 'zerocracy/judges-action')
  end

  def test_mask_to_regex_case_insensitive
    re = Fbe.mask_to_regex('Zerocracy/Fbe')
    assert_match(re, 'zerocracy/fbe')
  end

  def test_cannot_build_regex_from_mask_without_slash
    e = assert_raises(Fbe::Error) { Fbe.mask_to_regex('zerocracy') }
    assert_includes(e.message, 'zerocracy', 'the mask without a slash is not quoted in the error')
  end

  def test_cannot_build_regex_from_mask_with_empty_repo
    e = assert_raises(Fbe::Error) { Fbe.mask_to_regex('zerocracy/') }
    assert_includes(e.message, 'zerocracy/', 'the mask with an empty repo is not quoted in the error')
  end

  def test_cannot_build_regex_from_mask_with_empty_org
    e = assert_raises(Fbe::Error) { Fbe.mask_to_regex('/fbe') }
    assert_includes(e.message, '/fbe', 'the mask with an empty org is not quoted in the error')
  end

  def test_cannot_build_regex_from_empty_mask
    assert_raises(Fbe::Error) { Fbe.mask_to_regex('') }
  end

  def test_cannot_build_regex_from_mask_with_two_slashes
    e = assert_raises(Fbe::Error) { Fbe.mask_to_regex('zerocracy/a/b') }
    assert_includes(e.message, 'zerocracy/a/b', 'the mask with two slashes is not quoted in the error')
  end

  def test_cannot_build_regex_from_slash_only_mask
    assert_raises(Fbe::Error) { Fbe.mask_to_regex('/') }
  end

  def test_cannot_build_regex_from_mask_with_asterisk_in_org
    e = assert_raises(Fbe::Error) { Fbe.mask_to_regex('zero*/fbe') }
    assert_includes(e.message, 'zero*', 'the org with an asterisk is not quoted in the error')
  end

  def test_cannot_build_regex_from_random_mask_without_slash
    seed = Random.new_seed
    mask = "Ω#{Random.new(seed).rand(1_000_000)}λ"
    assert_raises(Fbe::Error, "the mask #{mask.inspect} is accepted, seed is #{seed}") { Fbe.mask_to_regex(mask) }
  end

  def test_cannot_unmask_repos_with_broken_exclusion_mask
    options = Judges::Options.new({ 'testing' => true, 'repositories' => 'yegor256/tacit,-zerocracy/a/b' })
    assert_raises(Fbe::Error) { Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL) }
  end

  def test_skips_mask_when_organization_listing_is_forbidden
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/orgs/foo/repos?per_page=100&type=all').to_return(status: 403)
    stub_request(:get, 'https://api.github.com/repos/bar/baz').to_return(
      body: '{"archived":false}', headers: { 'Content-Type' => 'application/json' }
    )
    options = Judges::Options.new({ 'repositories' => 'foo/*,bar/baz' })
    list = Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL)
    assert_equal(['bar/baz'], list, 'the forbidden mask is not skipped')
  end

  def test_keeps_repo_when_archived_check_fails
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(status: 500)
    options = Judges::Options.new({ 'repositories' => 'foo/bar' })
    list = Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL)
    assert_equal(['foo/bar'], list, 'the repo is not kept after a failed archived check')
  end

  def test_drops_repo_that_is_absent
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/bar').to_return(status: 404)
    stub_request(:get, 'https://api.github.com/repos/bar/baz').to_return(
      body: '{"archived":false}', headers: { 'Content-Type' => 'application/json' }
    )
    options = Judges::Options.new({ 'repositories' => 'foo/bar,bar/baz' })
    list = Fbe.unmask_repos(options:, global: {}, loog: Loog::NULL)
    assert_equal(['bar/baz'], list, 'the absent repo is not dropped')
  end

  def test_live_usage
    skip('Run it only manually, since it touches GitHub API')
    opts = Judges::Options.new({ 'repositories' => 'zerocracy/*,-zerocracy/judges-action,zerocracy/datum' })
    list = Fbe.unmask_repos(options: opts, global: {}, loog: Loog::NULL)
    assert_predicate(list.size, :positive?)
    assert_includes(list, 'zerocracy/pages-action')
    refute_includes(list, 'zerocracy/judges-action')
    refute_includes(list, 'zerocracy/datum')
  end
end
