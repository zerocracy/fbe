# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require_relative '../fbe'
require_relative 'fb'
require_relative 'overwrite'

# Run the block provided every X hours based on PMP configuration.
#
# Similar to Fbe.regularly but works with hour intervals instead of days.
# Executes a block periodically, maintaining a single fact that tracks the
# last execution time. The fact is overwritten on each run rather than
# creating new facts.
#
# @param [String] area The name of the PMP area
# @param [String] p_every_hours PMP property name for interval (defaults to 24 hours if not in PMP)
# @param [Factbase] fb The factbase (defaults to Fbe.fb)
# @param [String] judge The name of the judge (uses $judge global)
# @param [Loog] loog The logging facility (uses $loog global)
# @yield [Factbase::Fact] The judge fact to populate with execution details
# @return [nil] Nothing
# @raise [RuntimeError] If required parameters or globals are nil
# @note Skips execution if judge was run within the interval period
# @note Overwrites the 'when' property of existing judge fact
# @example Run a monitoring task every 6 hours
#   Fbe.repeatedly('monitoring', 'hours_between_checks') do |f|
#     f.servers_checked = check_all_servers
#     f.issues_found = count_issues
#     # PMP might have: hours_between_checks=6
#   end
def Fbe.repeatedly(area, p_every_hours, fb: Fbe.fb, judge: $judge, loog: $loog, &)
  raise 'The area is nil' if area.nil?
  raise 'The p_every_hours is nil' if p_every_hours.nil?
  raise 'The fb is nil' if fb.nil?
  raise 'The $judge is not set' if judge.nil?
  raise 'The $loog is not set' if loog.nil?
  pmp = fb.query("(and (eq what 'pmp') (eq area '#{area}') (exists #{p_every_hours}))").each.first
  hours = pmp.nil? ? 24 : pmp[p_every_hours].first
  recent = fb.query(
    "(and
      (eq what '#{judge}')
      (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '#{hours} hours')))"
  ).each.first
  if recent
    loog.info("#{$judge} was executed #{recent.when.ago} ago, skipping now (we run it every #{hours} hours)")
    return
  end
  f = fb.query("(and (eq what '#{judge}'))").each.first
  if f.nil?
    f = fb.insert
    f.what = judge
  end
  Fbe.overwrite(f, 'when', Time.now)
  yield fb.query("(and (eq what '#{judge}'))").each.first
  nil
end
