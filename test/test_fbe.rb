# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

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

  def test_documented_raise_tags_name_the_class_that_is_raised
    Dir[File.join(__dir__, '../lib/**/*.rb')].each do |f|
      tags = File.readlines(f).grep(/@raise \[/)
      tags.each do |t|
        refute_includes(t, '[RuntimeError]', "#{f} promises RuntimeError, but Fbe raises Fbe::Error")
      end
    end
  end

  def test_requires_every_runtime_dependency
    code = Dir[File.join(__dir__, '../lib/**/*.rb')].map { |f| File.read(f) }.join
    unused =
      Gem::Specification.load(File.join(__dir__, '../fbe.gemspec')).runtime_dependencies.reject do |d|
        Gem::Specification.find_by_name(d.name).full_require_paths.any? do |p|
          Dir[File.join(p, '**/*.rb')].any? do |f|
            code.include?("require '#{f.delete_prefix("#{p}/").delete_suffix('.rb')}'")
          end
        end
      end
    assert_empty(unused.map(&:name), 'these gems are declared in the gemspec, but never required')
  end
end
