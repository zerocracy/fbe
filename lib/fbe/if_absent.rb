# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase/light'
require 'others'
require 'time'
require_relative '../fbe'
require_relative 'fb'

# Injects a fact if it's absent in the factbase, otherwise returns nil.
#
# Checks if a fact with the same property values already exists. If not,
# creates a new fact. System properties (_id, _time, _version) are excluded
# from the uniqueness check.
#
# Here is what you do when you want to add a fact to the factbase, but
# don't want to make a duplicate of an existing one:
#
#  require 'fbe/if_absent'
#  n = Fbe.if_absent do |f|
#    f.what = 'something'
#    f.details = 'important'
#  end
#  return if n.nil?  # Fact already existed
#  n.when = Time.now # Add additional properties to the new fact
#
# This code will definitely create one fact with +what+ equals to +something+
# and +details+ equals to +important+, while the +when+ will be equal to the
# time of its first creation.
#
# @param [Factbase] fb The factbase to check and insert into (defaults to Fbe.fb)
# @param [Boolean] always If true, return the object in any case
# @yield [Factbase::Fact] A proxy fact object to set properties on
# @return [nil, Factbase::Fact] nil if fact exists, otherwise the newly created fact
# @note String values are properly escaped in queries
# @note Time values are converted to UTC ISO8601 format for comparison
# @example Ensure unique user registration
#   user = Fbe.if_absent do |f|
#     f.type = 'user'
#     f.email = 'john@example.com'
#   end
#   if user
#     user.registered_at = Time.now
#     puts "New user created"
#   else
#     puts "User already exists"
#   end
def Fbe.if_absent(fb: Fbe.fb, always: false) # rubocop:disable Metrics/PerceivedComplexity
  attrs = {}
  f =
    others(map: attrs) do |*args|
      k = args[0]
      if k.end_with?('=')
        k = k[0..-2].to_sym
        v = args[1]
        raise(Fbe::Error, "Can't set #{k} to nil") if v.nil?
        raise(Fbe::Error, "Can't set #{k} to empty string") if v.is_a?(String) && v.empty?
        @map[k] = v
      else
        @map[k.to_sym]
      end
    end
  yield(f)
  q = attrs.except(:_id, :_time, :_version).map do |k, v|
    vv = v.to_s
    if v.is_a?(String)
      vv = "'#{vv.gsub('"', '\\\\"').gsub("'", "\\\\'")}'"
    elsif v.is_a?(Time)
      vv = v.utc.iso8601
    end
    "(eq #{k} #{vv})"
  end.join(' ')
  q = "(and #{q})"
  before = fb.query(q).each.first
  return before if before && always
  return nil if before
  if Fbe.transactional?(fb)
    n = fb.insert
    attrs.each { |k, v| n.public_send(:"#{k}=", v) }
    return n
  end
  fb.txn do |fbt|
    n = fbt.insert
    attrs.each { |k, v| n.public_send(:"#{k}=", v) }
  end
  fb.query(q).each.first
end

# Is this factbase already inside a transaction?
#
# A transaction cannot be started inside another one, and a fact made inside
# one does not exist outside it. Both matter here: a caller that is already in
# a transaction must not have another opened for it, and the fact it gets back
# has to be the one its own transaction holds. The mark of being inside is a
# +Factbase::Light+ somewhere down the chain of decorators, which is what
# +Factbase#txn+ hands to its block.
#
# @param [Factbase] fb The factbase to look at
# @return [Boolean] TRUE if a transaction is already open on it
def Fbe.transactional?(fb)
  found = false
  probe = fb
  loop do
    found = true if probe.is_a?(Factbase::Light)
    iv = (probe.instance_variables & %i[@fb @origin @fact]).first
    break if iv.nil?
    probe = probe.instance_variable_get(iv)
  end
  found
end
