# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require_relative '../fbe'

# Converts number of seconds into text.
#
# The number of seconds is taken from the +fact+ provided, usually stored
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
  (Time.now + s).ago
end
