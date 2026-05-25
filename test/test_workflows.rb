# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'yaml'

class TestWorkflows < Minitest::Test
  def test_codecov_uses_rake_ruby_version
    root = File.expand_path('..', __dir__)
    codecov = YAML.safe_load_file(File.join(root, '.github', 'workflows', 'codecov.yml'))
    rake = YAML.safe_load_file(File.join(root, '.github', 'workflows', 'rake.yml'))
    codecov_steps = codecov.fetch('jobs').fetch('codecov').fetch('steps')
    codecov_step = codecov_steps.find { |step| step['uses'] == 'ruby/setup-ruby@v1' }
    codecov_ruby = codecov_step.fetch('with').fetch('ruby-version')
    rake_matrix = rake.fetch('jobs').fetch('rake').fetch('strategy').fetch('matrix')
    rake_ruby = rake_matrix.fetch('ruby').first
    assert_equal(rake_ruby, codecov_ruby)
  end
end
