# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'others'
require_relative '../fbe'
require_relative 'fb'

# Takes configuration parameter from the "PMP" fact.
#
# The factbase may have a few facts with the +what+ set to +pmp+ (stands for the
# "project management plan"). These facts contain information that configures
# the project. It is expected that every fact with the +what+ set to +pmp+ also
# contains the +area+ property, which is set to one of nine values: +scope+,
# +time+, +cost+, etc. (the nine process areas in the PMBOK).
#
# If a proper pmp fact is not found or the property is absent in the fact,
# this method throws an exception. The factbase must contain PMP-related facts.
# Most probably, a special judge must fill it up with such a fact.
#
# @param [Factbase] fb The factbase
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @return [String|Integer] The value of the property found
def Fbe.pmp(fb: Fbe.fb, global: $global, options: $options, loog: $loog)
  others do |*args1|
    area = args1.first
    unless %w[cost scope hr time procurement risk integration quality communication].include?(area.to_s)
      raise "Invalid area #{area.inspect} (not part of PMBOK)"
    end
    others do |*args2|
      param = args2.first
      f = Fbe.fb(global:, fb:, options:, loog:).query("(and (eq what 'pmp') (eq area '#{area}'))").each.to_a.first
      raise "Unknown area #{area.inspect}" if f.nil?
      r = f[param]
      raise "Unknown property #{param.inspect} in the #{area.inspect} area" if r.nil?
      r.first
    end
  end
end
