# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Makes a copy of a fact, preserving the target identity and timestamp.
#
# All properties from the +source+ will be copied to the +target+, except +_id+,
# +_time+, and those listed in the +except+ array. Only copies properties that
# don't already exist in the target. Multi-valued properties are copied with all
# their values.
#
# @param [Factbase::Fact] source The source fact to copy from
# @param [Factbase::Fact] target The target fact to copy to
# @param [Array<String>] except List of property names to NOT copy (defaults to empty)
# @return [Integer] The number of property values that were copied
# @raise [Fbe::Error] If source, target, or except is nil
# @note Existing properties in target are preserved (not overwritten)
# @example Copy properties while preserving identity and timestamp
#   source = fb.query('(eq type "user")').first
#   target = fb.insert
#   count = Fbe.copy(source, target)
#   puts "Copied #{count} property values"
def Fbe.copy(source, target, except: [])
  raise(Fbe::Error, 'The source is nil') if source.nil?
  raise(Fbe::Error, 'The target is nil') if target.nil?
  raise(Fbe::Error, 'The except is nil') if except.nil?
  except = except.map(&:to_s) + %w[_id _time]
  copied = 0
  source.all_properties.each do |k|
    next unless target[k].nil?
    next if except.include?(k)
    source[k].each do |v|
      target.public_send(:"#{k}=", v)
      copied += 1
    end
  end
  copied
end
