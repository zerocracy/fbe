# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'English'
require_relative 'lib/fbe'

Gem::Specification.new do |s|
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = '>=3.0'
  s.name = 'fbe'
  s.version = Fbe::VERSION
  s.license = 'MIT'
  s.summary = 'FactBase Extended (FBE), a collection of utility classes for Zerocracy judges'
  s.description =
    'A collection of extensions for a factbase, helping the judges of Zerocracy ' \
    'manipulate the facts and create new ones'
  s.authors = ['Yegor Bugayenko']
  s.email = 'yegor256@gmail.com'
  s.homepage = 'https://github.com/zerocracy/fbe'
  s.files = `git ls-files | grep -v -E '^(test/|renovate|coverage)'`.split($RS)
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.add_dependency 'backtrace', '~>0.4'
  s.add_dependency 'baza.rb', '~>0.9'
  s.add_dependency 'decoor', '~>0.1'
  s.add_dependency 'ellipsized', '~>0.3'
  s.add_dependency 'factbase', '~>0.11'
  s.add_dependency 'faraday', '~>2.0'
  s.add_dependency 'faraday-http-cache', '~>2.5'
  s.add_dependency 'faraday-multipart', '~>1.1'
  s.add_dependency 'faraday-retry', '~>2.3'
  s.add_dependency 'filesize', '~>0.2'
  s.add_dependency 'graphql-client', '~>0.26'
  s.add_dependency 'intercepted', '~>0.2'
  s.add_dependency 'joined', '~>0.1'
  s.add_dependency 'judges', '~>0.46'
  s.add_dependency 'liquid', '~>5.5'
  s.add_dependency 'loog', '~>0.6'
  s.add_dependency 'obk', '~>0.3'
  s.add_dependency 'octokit', '~>10.0'
  s.add_dependency 'others', '~>0.1'
  s.add_dependency 'sqlite3', '~> 2.6'
  s.add_dependency 'tago', '~>0.1'
  s.add_dependency 'veils', '~>0.4'
  s.add_dependency 'verbose', '~>0.0'
  s.metadata['rubygems_mfa_required'] = 'true'
end
