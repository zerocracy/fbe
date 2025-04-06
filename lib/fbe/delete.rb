# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Delete a few properties from the fact.
#
# @param [Factbase::Fact] source The source
# @param [Array<String>] props List of properties to delete
# @param [Factbase] fb The factbase
# @param [String] id The unique ID of the fact
# @return [Factbase::Fact] New fact
def Fbe.delete(fact, *props, fb: Fbe.fb, id: '_id')
  raise 'The fact is nil' if fact.nil?
  i = fact[id]
  raise "There is no #{id.inspect} in the fact" if i.nil?
  i = i.first
  before = {}
  fact.all_properties.each do |k|
    next if props.include?(k)
    fact[k].each do |v|
      before[k] = v
    end
  end
  fb.query("(eq #{id} #{i})").delete!
  c = fb.insert
  before.each do |k, v|
    c.send(:"#{k}=", v)
  end
  c
end
