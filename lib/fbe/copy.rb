# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Makes a copy of a fact, moving all properties to a new fact.
#
# All properties from the +source+ will be copied to the +target+, except those
# listed in the +except+ array. Only copies properties that don't already exist
# in the target. Multi-valued properties are copied with all their values.
#
# @param [Factbase::Fact] source The source fact to copy from
# @param [Factbase::Fact] target The target fact to copy to
# @param [Array<String>] except List of property names to NOT copy (defaults to empty)
# @return [Integer] The number of property values that were copied
# @raise [RuntimeError] If source, target, or except is nil
# @note Existing properties in target are preserved (not overwritten)
# @example Copy all properties except timestamps
#   source = fb.query('(eq type "user")').first
#   target = fb.insert
#   count = Fbe.copy(source, target, except: ['_time', '_id'])
#   puts "Copied #{count} property values"
def Fbe.copy(source, target, except: [])
  raise 'The source is nil' if source.nil?
  raise 'The target is nil' if target.nil?
  raise 'The except is nil' if except.nil?
  copied = 0
  source.all_properties.each do |k|
    next unless target[k].nil?
    next if except.include?(k)
    source[k].each do |v|
      target.send(:"#{k}=", v)
      copied += 1
    end
  end
  copied
end
