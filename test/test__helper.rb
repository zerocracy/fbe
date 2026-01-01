# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

$stdout.sync = true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
require 'simplecov-cobertura'
unless SimpleCov.running || ARGV.include?('--no-cov')
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  )
  SimpleCov.minimum_coverage 80
  SimpleCov.minimum_coverage_by_file 80
  SimpleCov.start do
    add_filter 'vendor/'
    add_filter 'target/'
    add_filter 'test/'
    add_filter 'lib/fbe/github_graph.rb'
    track_files 'lib/**/*.rb'
    track_files '*.rb'
  end
end

require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]
Minitest.load :minitest_reporter

require 'loog'
require 'minitest/autorun'
require 'minitest/mock'
require 'minitest/stub_const'
require 'webmock/minitest'
require_relative '../lib/fbe'

# Parent class for all tests.
class Fbe::Test < Minitest::Test
  def fake_loog
    Loog::NULL
  end
end
