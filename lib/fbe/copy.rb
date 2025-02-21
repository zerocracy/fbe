# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Makes a copy of a fact, moving all properties to a new fact.
#
# All properties from the +source+ will be copied to the +target+, except those
# listed in the +except+.
#
# @param [Factbase::Fact] source The source
# @param [Factbase::Fact] target The targer
# @param [Array<String>] except List of properties to NOT copy
# @return [Integer] How many properties were copied
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
