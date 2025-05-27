# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require_relative '../fbe'

# Converts number of seconds into human-readable time format.
#
# The number of seconds is taken from the +fact+ provided, usually stored
# there in the +seconds+ property. The seconds are formatted into a
# human-readable string like "3 days ago" or "5 hours ago" using the
# tago gem.
#
# @param [Factbase::Fact] fact The fact containing the seconds property
# @param [String, Symbol] prop The property name with seconds (defaults to :seconds)
# @return [String] Human-readable time interval (e.g., "2 weeks ago", "3 hours ago")
# @raise [RuntimeError] If the specified property doesn't exist in the fact
# @note Uses the tago gem's ago method for formatting
# @example Format elapsed time from a fact
#   build_fact = fb.query('(eq type "build")').first
#   build_fact.duration = 7200  # 2 hours in seconds
#   puts Fbe.sec(build_fact, :duration)  # => "2 hours ago"
def Fbe.sec(fact, prop = :seconds)
  s = fact[prop.to_s]
  raise "There is no #{prop.inspect} property" if s.nil?
  s = s.first.to_i
  (Time.now + s).ago
end
