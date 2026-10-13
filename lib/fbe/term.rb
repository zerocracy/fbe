# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require_relative '../fbe'

# An equality term of the query language, holding a value the parser reads back.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class Fbe::Term
  # Ctor.
  # @param [String] prop The name of the property
  # @param [Object] value Its value
  def initialize(prop, value)
    @prop = prop
    @value = value
  end

  # @return [String] The term, spelled the way the parser expects it
  # @raise [Fbe::Error] If the value is an array or the parser can't read it back
  def to_s
    "(eq #{@prop} #{literal})"
  end

  private

  def literal
    return "'#{@value.gsub('"', '\\\\"').gsub("'", "\\\\'")}'" if @value.is_a?(String)
    return @value.utc.iso8601 if @value.is_a?(Time)
    return @value.to_s if @value.is_a?(Integer) || (@value.is_a?(Float) && @value.finite?)
    raise(Fbe::Error, "Can't match #{@prop} by an array, only by one value") if @value.is_a?(Array)
    raise(Fbe::Error, "Can't match #{@prop} by #{@value.inspect}, the query has no way to spell it")
  end
end
