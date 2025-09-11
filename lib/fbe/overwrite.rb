# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Overwrites a property in the fact by recreating the entire fact.
#
# If the property doesn't exist in the fact, it will be added. If it does
# exist, the entire fact will be destroyed, a new fact created with all
# existing properties, and the specified property set with the new value.
#
# It is important that the fact has the +_id+ property. If it doesn't,
# an exception will be raised.
#
# @param [Factbase::Fact] fact The fact to modify (must have _id property)
# @param [String, Hash] property_or_hash The name of the property to set, or a hash of properties
# @param [Any] values The value to set (can be any type, including array) - ignored if first param is Hash
# @param [Factbase] fb The factbase to use (defaults to Fbe.fb)
# @return [nil] Nothing
# @raise [RuntimeError] If fact is nil, has no _id, or property is not a String
# @note This operation preserves all other properties during recreation
# @note If property already has the same single value, no changes are made
# @example Update a user's status
#   user = fb.query('(eq login "john")').first
#   Fbe.overwrite(user, 'status', 'active')
#   # All properties preserved, only 'status' is set to 'active'
# @example Update multiple properties at once
#   user = fb.query('(eq login "john")').first
#   Fbe.overwrite(user, status: 'active', role: 'admin')
#   # All properties preserved, 'status' and 'role' are updated
def Fbe.overwrite(fact, property_or_hash, values = nil, fb: Fbe.fb, fid: '_id')
  raise 'The fact is nil' if fact.nil?
  raise 'The fb is nil' if fb.nil?
  
  # Handle Hash input (new API)
  if property_or_hash.is_a?(Hash)
    property_or_hash.each do |property, val|
      Fbe.overwrite(fact, property.to_s, val, fb: fb, fid: fid)
    end
    return
  end
  
  # Handle String input (original API)
  property = property_or_hash
  raise "The property is not a String but #{property.class} (#{property})" unless property.is_a?(String)
  raise 'The values is nil' if values.nil?
  values = [values] unless values.is_a?(Array)
  return fact if !fact[property].nil? && fact[property].one? && values.one? && fact[property].first == values.first
  if fact[property].nil?
    values.each do |v|
      fact.send(:"#{property}=", v)
    end
    return
  end
  before = {}
  fact.all_properties.each do |prop|
    before[prop.to_s] = fact[prop]
  end
  id = fact[fid]&.first
  raise "There is no #{fid} in the fact, cannot use Fbe.overwrite" if id.nil?
  raise "No facts by #{fid} = #{id}" if fb.query("(eq #{fid} #{id})").delete!.zero?
  fb.txn do |fbt|
    n = fbt.insert
    before[property.to_s] = values
    before.each do |k, vv|
      next unless n[k].nil?
      vv.each do |v|
        n.send(:"#{k}=", v)
      end
    end
  end
  nil
end
