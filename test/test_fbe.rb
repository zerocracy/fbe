# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'yaml'
require_relative '../lib/fbe'
require_relative 'test__helper'

# Main module test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestFbe < Fbe::Test
  def test_simple
    refute_nil(Fbe::VERSION)
  end

  def test_error_is_not_a_runtime_error
    assert_kind_of(StandardError, Fbe::Error.new)
    refute_kind_of(RuntimeError, Fbe::Error.new)
  end

  def test_all_workflows_have_timeout_minutes
    Dir[File.join(__dir__, '../.github/workflows/*.yml')].each do |f|
      doc = YAML.safe_load_file(f)
      refute(doc.key?('timeout-minutes'), "#{f} sets timeout-minutes where GitHub ignores it")
      jobs = doc['jobs']
      refute_empty(jobs, "#{f} has no jobs")
      jobs.each do |name, job|
        minutes = job['timeout-minutes']
        assert_kind_of(Integer, minutes, "#{f}: the job '#{name}' has no integer timeout-minutes")
        assert_operator(minutes, :>, 0, "#{f}: the job '#{name}' has a non-positive timeout")
        assert_operator(minutes, :<=, 30, "#{f}: the job '#{name}' may hold a runner for #{minutes} minutes")
      end
    end
  end

  def test_rake_workflow_caps_its_timeout_like_the_others
    rake = File.join(__dir__, '../.github/workflows/rake.yml')
    minutes = YAML.safe_load_file(rake).dig('jobs', 'rake', 'timeout-minutes')
    others = Dir[File.join(__dir__, '../.github/workflows/*.yml')] - [rake]
    longest = others.map { |f| YAML.safe_load_file(f)['jobs'].values.map { |j| j['timeout-minutes'] }.max }
    assert_operator(minutes, :<=, longest.max, 'The rake job may wait longer than every other workflow')
  end

  def test_rake_workflow_runs_the_suite_on_several_operating_systems
    job = YAML.safe_load_file(File.join(__dir__, '../.github/workflows/rake.yml'))['jobs']['rake']
    assert_operator(job.dig('strategy', 'matrix', 'os').size, :>, 1, 'The suite runs on a single OS')
    assert_includes(job['steps'].map { |step| step['run'] }, 'bundle exec rake')
  end

  def test_documented_raise_tags_name_the_class_that_is_raised
    Dir[File.join(__dir__, '../lib/**/*.rb')].each do |f|
      tags = File.readlines(f).grep(/@raise \[/)
      tags.each do |t|
        refute_includes(t, '[RuntimeError]', "#{f} promises RuntimeError, but Fbe raises Fbe::Error")
      end
    end
  end
end
