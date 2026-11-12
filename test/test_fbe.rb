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

  def test_declares_every_gem_it_requires
    declared = Gem::Specification.load(File.join(__dir__, '../fbe.gemspec')).runtime_dependencies.map(&:name)
    undeclared =
      Dir[File.join(__dir__, '../lib/**/*.rb')].flat_map { |f| File.read(f).scan(/^require '([^']+)'$/).flatten }
        .filter_map do |r|
          g = Gem::Specification.find_by_path(r)&.name
          next if g.nil? || declared.include?(g)
          g if Dir[File.join(Gem.default_specifications_dir, "#{g}-*.gemspec")].empty?
        end
    assert_empty(undeclared.uniq, 'these gems are required under lib, but not declared in the gemspec')
  end
end
