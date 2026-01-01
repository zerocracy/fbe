# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Delete one value of a property.
#
# This method doesn't modify the original fact. Instead, it deletes the existing
# fact from the factbase and creates a new one with all properties except the one
# specified for deletion.
#
# @param [Factbase::Fact] fact The fact to delete properties from (must have an ID)
# @param [String] prop The property name
# @param [Any] value The value to delete
# @param [Factbase] fb The factbase to use (defaults to Fbe.fb)
# @param [String] id The property name used as unique identifier (defaults to '_id')
# @return [nil] Nothing
def Fbe.delete_one(fact, prop, value, fb: Fbe.fb, id: '_id')
  raise 'The fact is nil' if fact.nil?
  i = fact[id]
  raise "There is no #{id.inspect} in the fact" if i.nil?
  i = i.first
  before = {}
  fact.all_properties.each do |k|
    before[k] = fact[k]
  end
  return unless before[prop]
  before[prop] = before[prop] - [value]
  before.delete(prop) if before[prop].empty?
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
