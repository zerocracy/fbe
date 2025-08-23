# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Delete properties from a fact by creating a new fact without them.
#
# This method doesn't modify the original fact. Instead, it deletes the existing
# fact from the factbase and creates a new one with all properties except those
# specified for deletion.
#
# @param [Factbase::Fact] fact The fact to delete properties from (must have an ID)
# @param [Array<String>] props List of property names to delete
# @param [Factbase] fb The factbase to use (defaults to Fbe.fb)
# @param [String] id The property name used as unique identifier (defaults to '_id')
# @return [nil] Nothing
# @raise [RuntimeError] If fact is nil, has no ID, or ID property doesn't exist
# @example Delete multiple properties from a fact
#   fact = fb.query('(eq type "user")').first
#   new_fact = Fbe.delete(fact, 'age', 'city')
#   # new_fact will have all properties except 'age' and 'city'
def Fbe.delete(fact, *props, fb: Fbe.fb, id: '_id')
  raise 'The fact is nil' if fact.nil?
  i = fact[id]
  raise "There is no #{id.inspect} in the fact" if i.nil?
  i = i.first
  before = {}
  fact.all_properties.each do |k|
    next if props.include?(k)
    before[k] = fact[k]
  end
  before.delete(id)
  fb.query("(eq #{id} #{i})").delete!
  fb.txn do |fbt|
    c = fbt.insert
    before.each do |k, vv|
      next unless c[k].nil?
      vv.each do |v|
        c.send(:"#{k}=", v)
      end
    end
  end
  nil
end
