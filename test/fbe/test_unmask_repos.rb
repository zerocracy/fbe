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
