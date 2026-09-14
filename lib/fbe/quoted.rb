# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require_relative '../fbe'

# Renders a value the way a Factbase query expects to see it.
#
# A String is wrapped in single quotes, with the quotes inside it escaped.
# A Time is rendered in ISO 8601, in UTC. Everything else goes in as is.
# Without this, a String value lands in the query as a bare word and the
# parser reads it as a property name, so the query matches nothing.
#
# @example Building a query out of an arbitrary value
#   fb.query("(eq name #{Fbe.quoted('alpha')})")
#   # => the query is "(eq name 'alpha')"
#
# @param [Any] value The value to render
# @return [String] The value, ready to be put into a query
def Fbe.quoted(value)
  case value
  when String
    "'#{value.gsub('"', '\\\\"').gsub("'", "\\\\'")}'"
  when Time
    value.utc.iso8601
  else
    value.to_s
  end
end
