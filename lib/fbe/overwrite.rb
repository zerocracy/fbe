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
# @param [String] property The name of the property to set
# @param [Any] value The value to set (can be any type)
# @param [Factbase] fb The factbase to use (defaults to Fbe.fb)
# @return [nil] Nothing
# @raise [RuntimeError] If fact is nil, has no _id, or property is not a String
# @note This operation preserves all other properties during recreation
# @note If property already has the same single value, no changes are made
# @example Update a user's status
#   user = fb.query('(eq login "john")').first
#   updated_user = Fbe.overwrite(user, 'status', 'active')
#   # All properties preserved, only 'status' is set to 'active'
def Fbe.overwrite(fact, property, value, fb: Fbe.fb)
  raise 'The fact is nil' if fact.nil?
  raise 'The fb is nil' if fb.nil?
  raise "The property is not a String but #{property.class} (#{property})" unless property.is_a?(String)
  return fact if !fact[property].nil? && fact[property].size == 1 && fact[property].first == value
  before = {}
  fact.all_properties.each do |prop|
    before[prop.to_s] = fact[prop]
  end
  id = fact['_id']&.first
  raise 'There is no _id in the fact, cannot use Fbe.overwrite' if id.nil?
  raise "No facts by _id = #{id}" if fb.query("(eq _id #{id})").delete!.zero?
  fb.txn do |fbt|
    n = fbt.insert
    before[property.to_s] = [value]
    before.each do |k, vv|
      next unless n[k].nil?
      vv.each do |v|
        n.send(:"#{k}=", v)
      end
    end
  end
  nil
end
