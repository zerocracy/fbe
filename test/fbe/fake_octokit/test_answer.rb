# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'sawyer'
require_relative '../../../lib/fbe/fake_octokit/answer'
require_relative '../../test__helper'

# Test for Fbe::FakeOctokit::Answer.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestAnswer < Fbe::Test
  def test_is_a_sawyer_resource
    agent = Sawyer::Agent.new('https://api.github.com')
    answer = Fbe::FakeOctokit::Answer.new(agent, { id: 7, name: 'foo' })
    assert_kind_of(Sawyer::Resource, answer)
    assert_equal(7, answer.id)
    assert_equal('foo', answer[:name])
    assert_equal('foo', answer['name'])
  end

  def test_does_not_respond_to_deconstruct_keys
    agent = Sawyer::Agent.new('https://api.github.com')
    answer = Fbe::FakeOctokit::Answer.new(agent, { id: 7 })
    refute_respond_to(answer, :deconstruct_keys)
  end

  def test_pattern_matching_does_not_match
    agent = Sawyer::Agent.new('https://api.github.com')
    answer = Fbe::FakeOctokit::Answer.new(agent, { id: 7 })
    matched =
      case answer
      in { id: 7 }
        true
      else
        false
      end
    refute(matched)
  end

  def test_does_not_equal_hash
    agent = Sawyer::Agent.new('https://api.github.com')
    answer = Fbe::FakeOctokit::Answer.new(agent, { id: 7 })
    refute_equal({ id: 7 }, answer)
    refute_equal(answer, { id: 7 })
  end

  def test_does_not_equal_another_answer
    agent = Sawyer::Agent.new('https://api.github.com')
    first = Fbe::FakeOctokit::Answer.new(agent, { id: 7 })
    second = Fbe::FakeOctokit::Answer.new(agent, { id: 7 })
    refute_equal(first, second)
  end

  def test_does_not_respond_to_keys
    agent = Sawyer::Agent.new('https://api.github.com')
    answer = Fbe::FakeOctokit::Answer.new(agent, { id: 7 })
    refute_respond_to(answer, :keys)
  end

  def test_to_attrs_equals_hash
    agent = Sawyer::Agent.new('https://api.github.com')
    answer = Fbe::FakeOctokit::Answer.new(agent, { id: 7, name: 'bar' })
    assert_equal({ id: 7, name: 'bar' }, answer.to_attrs)
  end
end
