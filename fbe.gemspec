# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
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
  s.homepage = 'http://github.com/zerocracy/fbe'
  s.files = `git ls-files`.split($RS)
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.add_dependency 'backtrace', '~>0'
  s.add_dependency 'baza.rb', '~>0'
  s.add_dependency 'decoor', '~>0'
  s.add_dependency 'factbase', '>=0.9.3'
  s.add_dependency 'faraday', '~>2'
  s.add_dependency 'faraday-http-cache', '~>2'
  s.add_dependency 'faraday-multipart', '~>1'
  s.add_dependency 'faraday-retry', '~>2'
  s.add_dependency 'graphql-client', '~>0'
  s.add_dependency 'judges', '~>0'
  s.add_dependency 'liquid', '5.5.1'
  s.add_dependency 'loog', '~>0'
  s.add_dependency 'obk', '~>0'
  s.add_dependency 'octokit', '~>10'
  s.add_dependency 'others', '~>0'
  s.add_dependency 'tago', '~>0'
  s.add_dependency 'verbose', '~>0'
  s.metadata['rubygems_mfa_required'] = 'true'
end
