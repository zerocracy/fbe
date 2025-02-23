# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'

# Converts number of seconds into text.
#
# THe number of seconds is taken from the +fact+ provided, usually stored
# there in the +seconds+ property. The seconds are formatted to hours,
# days, or weeks.
#
# @param [Factbase::Fact] fact The fact, where to get the number of seconds
# @param [String] prop The property in the fact, with the seconds
# @return [String] Time interval as a text
def Fbe.sec(fact, prop = :seconds)
  s = fact[prop.to_s]
  raise "There is no #{prop.inspect} property" if s.nil?
  s = s.first.to_i
  if s < 60
    format('%d seconds', s)
  elsif s < 60 * 60
    format('%d minutes', s / 60)
  elsif s < 60 * 60 * 24
    format('%d hours', s / (60 * 60))
  elsif s < 7 * 60 * 60 * 24
    format('%d days', s / (60 * 60 * 24))
  else
    format('%d weeks', s / (7 * 60 * 60 * 24))
  end
end
