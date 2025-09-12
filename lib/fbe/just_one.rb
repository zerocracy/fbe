# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'others'
require 'time'
require_relative '../fbe'
require_relative 'fb'

# Ensures exactly one fact exists with the specified attributes in the factbase.
#
# This method creates a new fact if none exists with the given attributes,
# or returns an existing fact if one already matches. Useful for preventing
# duplicate facts while ensuring required facts exist.
#
# @example Creating or finding a unique fact
#   require 'fbe/just_one'
#   fact = Fbe.just_one do |f|
#     f.what = 'github_issue'
#     f.issue_id = 123
#     f.repository = 'zerocracy/fbe'
#   end
#   # Returns existing fact if one exists with these exact attributes,
#   # otherwise creates and returns a new fact
#
# @example Attributes are matched exactly (case-sensitive)
#   Fbe.just_one { |f| f.name = 'Test' }  # Creates fact with name='Test'
#   Fbe.just_one { |f| f.name = 'test' }  # Creates another fact (different case)
#
# @param [Factbase] fb The factbase to search/insert into (defaults to Fbe.fb)
# @yield [Factbase::Fact] Block to set attributes on the fact
# @return [Factbase::Fact] The existing or newly created fact
# @note System attributes (_id, _time, _version) are ignored when matching
def Fbe.just_one(fb: Fbe.fb)
  attrs = {}
  f =
    others(map: attrs) do |*args|
      k = args[0]
      if k.end_with?('=')
        @map[k[0..-2].to_sym] = args[1]
      else
        @map[k.to_sym]
      end
    end
  yield f
  q = attrs.except('_id', '_time', '_version').map do |k, v|
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
  return before unless before.nil?
  n = fb.insert
  attrs.each { |k, v| n.send(:"#{k}=", v) }
  n
end
