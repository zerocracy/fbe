# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'yaml'

class TestWorkflows < Minitest::Test
  def test_codecov_uses_rake_ruby_version
    root = File.expand_path('..', __dir__)
    c = YAML.safe_load_file(File.join(root, '.github', 'workflows', 'codecov.yml'))
    r = YAML.safe_load_file(File.join(root, '.github', 'workflows', 'rake.yml'))
    ss = c.fetch('jobs').fetch('codecov').fetch('steps')
    s = ss.find { |step| step['uses'] == 'ruby/setup-ruby@v1' }
    cv = s.fetch('with').fetch('ruby-version')
    m = r.fetch('jobs').fetch('rake').fetch('strategy').fetch('matrix')
    rv = m.fetch('ruby').first
    assert_equal(rv, cv)
  end
end
