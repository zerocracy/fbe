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
  # @param [String] prop The name of the property, @param [Any] value Its value
  def initialize(prop, value)
    @prop = prop
    @value = value
  end

  # @return [String] The term, spelled the way the parser expects it
  def to_s
    "(eq #{@prop} #{literal})"
  end

  private

  def literal
    case @value
    when String
      "'#{@value.gsub('"', '\\\\"').gsub("'", "\\\\'")}'"
    when Time
      @value.utc.iso8601
    else
      @value.to_s
    end
  end
end
