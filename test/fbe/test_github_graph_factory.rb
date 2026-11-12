# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/github_graph'
require_relative '../test__helper'

class TestGithubGraphFactory < Fbe::Test
  def test_reuses_the_client_within_one_global_context
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    first = Fbe.github_graph(options:, global:, loog: Loog::NULL)
    second = Fbe.github_graph(options:, global:, loog: Loog::NULL)
    assert_same(first, second, 'repeated calls must reuse the same GraphQL client')
  end

  def test_selects_the_fake_client_for_uppercase_true
    options = Judges::Options.new({ 'testing' => 'TRUE' })
    graph = Fbe.github_graph(options:, global: {}, loog: Loog::NULL)
    assert_instance_of(Fbe::Graph::Fake, graph)
  end

  def test_selects_the_real_client_for_mixed_case_false
    options = Judges::Options.new({ 'testing' => 'False' })
    graph = Fbe.github_graph(options:, global: {}, loog: Loog::NULL)
    assert_instance_of(Fbe::Graph, graph)
  end

  def test_passes_the_environment_token_when_the_option_is_absent
    options = Judges::Options.new({})
    environment = ->(key, default) { key == 'GITHUB_TOKEN' ? 'synthetic-environment-token' : default }
    token =
      ENV.stub(:fetch, environment) do
        Fbe::Graph.stub(:new, ->(token:) { token }) do
          Fbe.github_graph(options:, global: {}, loog: Loog::NULL)
        end
      end
    assert_equal('synthetic-environment-token', token)
  end
end
