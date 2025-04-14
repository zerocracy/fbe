# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

$stdout.sync = true

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
    track_files 'lib/**/*.rb'
    track_files '*.rb'
  end
end

require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

require 'minitest/autorun'
require 'webmock/minitest'
require_relative '../lib/fbe'

# Parent class for all tests.
class Fbe::Test < Minitest::Test
end
