# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'others'
require 'tago'
require_relative '../fbe'
require_relative 'fb'
require_relative 'overwrite'
require_relative 'pmp'

# Run the block provided every X hours based on PMP configuration.
#
# Similar to Fbe.regularly but works with hour intervals instead of days.
# Executes a block periodically, maintaining a single fact that tracks the
# last execution time. The fact is overwritten on each run rather than
# creating new facts: a property set by the block replaces the value it
# got in the previous run.
#
# @param [String] area The name of the PMP area
# @param [String] p_every_hours PMP property name for interval (defaults to the pmp.xml value, or 24 hours)
# @param [Factbase] fb The factbase (defaults to Fbe.fb)
# @param [String] judge The name of the judge (uses $judge global)
# @param [Loog] loog The logging facility (uses $loog global)
# @param [Hash] global Hash of global options (uses $global), needed to read pmp.xml defaults
# @param [Judges::Options] options The options (uses $options), needed to read pmp.xml defaults
# @yield [Factbase::Fact] The judge fact to populate with execution details
# @return [nil] Nothing
# @raise [Fbe::Error] If required parameters or globals are nil
# @note Skips execution if judge was run within the interval period
# @note Overwrites the 'when' property of existing judge fact
# @example Run a monitoring task every 6 hours
#   Fbe.repeatedly('monitoring', 'hours_between_checks') do |f|
#     f.servers_checked = check_all_servers
#     f.issues_found = count_issues
#     # PMP might have: hours_between_checks=6
#   end
def Fbe.repeatedly( # rubocop:disable Metrics/AbcSize
  area, p_every_hours,
  fb: Fbe.fb, judge: $judge, loog: $loog, global: $global, options: $options, &
)
  raise(Fbe::Error, 'The area is nil') if area.nil?
  raise(Fbe::Error, 'The p_every_hours is nil') if p_every_hours.nil?
  raise(Fbe::Error, 'The fb is nil') if fb.nil?
  raise(Fbe::Error, 'The $judge is not set') if judge.nil?
  raise(Fbe::Error, 'The $loog is not set') if loog.nil?
  raise(Fbe::Error, 'A block is required by repeatedly') unless block_given?
  pmp = fb.query("(and (eq what 'pmp') (eq area '#{area.gsub("'", "\\\\'")}') (exists #{p_every_hours}))").each.first
  hours =
    if pmp.nil?
      begin
        Fbe.pmp(fb:, global:, options:, loog:).public_send(area).public_send(p_every_hours)
      rescue Fbe::Error
        24
      end
    else
      pmp[p_every_hours].first
    end
  marker = "(and (eq what 'repeatedly') (eq judge '#{judge.gsub("'", "\\\\'")}'))"
  recent = fb.query(
    "(and
      #{marker}
      (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '#{hours} hours')))"
  ).each.first
  if recent
    loog.info("#{judge} was executed #{recent.when.ago} ago, skipping now (we run it every #{hours} hours)")
    return
  end
  f = fb.query(marker).each.first
  if f.nil?
    f = fb.insert
    f.what = 'repeatedly'
    f.judge = judge
  end
  attrs = {}
  yield(
    others(fact: f, map: attrs) do |k, *rest|
      next @fact.public_send(k, *rest) unless k.end_with?('=')
      (@map[k[0..-2]] ||= []) << rest.first
    end
  )
  Fbe.overwrite(f, attrs.merge('when' => Time.now), fb:)
  nil
end
