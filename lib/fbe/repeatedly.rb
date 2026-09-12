# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'others'
require 'tago'
require_relative '../fbe'
require_relative 'fb'
require_relative 'overwrite'

# Run the block provided every X hours based on PMP configuration.
#
# Similar to Fbe.regularly but works with hour intervals instead of days.
# Executes a block periodically, maintaining a single fact that tracks the
# last execution time. The fact is overwritten on each run rather than
# creating new facts: a property set by the block replaces the value it
# got in the previous run.
#
# @param [String] area The name of the PMP area
# @param [String] p_every_hours PMP property name for interval (defaults to 24 hours if not in PMP)
# @param [Factbase] fb The factbase (defaults to Fbe.fb)
# @param [String] judge The name of the judge (uses $judge global)
# @param [Loog] loog The logging facility (uses $loog global)
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
def Fbe.repeatedly(area, p_every_hours, fb: Fbe.fb, judge: $judge, loog: $loog, &)
  raise(Fbe::Error, 'The area is nil') if area.nil?
  raise(Fbe::Error, 'The p_every_hours is nil') if p_every_hours.nil?
  raise(Fbe::Error, 'The fb is nil') if fb.nil?
  raise(Fbe::Error, 'The $judge is not set') if judge.nil?
  raise(Fbe::Error, 'The $loog is not set') if loog.nil?
  raise(Fbe::Error, 'A block is required by repeatedly') unless block_given?
  pmp = fb.query("(and (eq what 'pmp') (eq area '#{area.gsub("'", "\\\\'")}') (exists #{p_every_hours}))").each.first
  hours = pmp.nil? ? 24 : pmp[p_every_hours].first
  marker = "(and (eq what 'repeatedly') (eq judge '#{judge.gsub("'", "\\\\'")}'))"
  fresh =
    "(and
      #{marker}
      (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '#{hours} hours')))"
  recent, born, previous = Fbe.claim(fb, marker, fresh, judge)
  if recent
    loog.info("#{judge} was executed #{recent.when.ago} ago, skipping now (we run it every #{hours} hours)")
    return
  end
  attrs = {}
  begin
    yield(
      others(fact: fb.query(marker).each.first, map: attrs) do |k, *rest|
        next @fact.public_send(k, *rest) unless k.end_with?('=')
        (@map[k[0..-2]] ||= []) << rest.first
      end
    )
  rescue StandardError
    Fbe.unclaim(fb, marker, born, previous)
    raise
  end
  Fbe.overwrite(fb.query(marker).each.first, attrs, fb:) unless attrs.empty?
  nil
end

# Claim the interval marker of a judge, so that nobody else starts the same work.
#
# The check for a recent run and the write of the marker happen in one
# transaction. When the factbase is already inside a transaction, that one is
# used, since Factbase refuses a nested transaction and the outer one gives the
# same atomicity.
#
# @param [Factbase] fb The factbase to work with
# @param [String] marker The query that finds the marker of this judge
# @param [String] fresh The query that finds the marker if it is recent enough
# @param [String] judge The name of the judge
# @return [Array] The recent marker (or nil), whether the marker was just born,
#   and the timestamp the marker carried before
def Fbe.claim(fb, marker, fresh, judge)
  recent = nil
  born = false
  previous = nil
  once =
    lambda do |t|
      recent = t.query(fresh).each.first
      next unless recent.nil?
      m = t.query(marker).each.first
      if m.nil?
        m = t.insert
        m.what = 'repeatedly'
        m.judge = judge
        m.when = Time.now
        born = true
      else
        previous = m['when']&.first
        Fbe.overwrite(m, 'when', Time.now, fb: t)
      end
    end
  begin
    fb.txn { |fbt| once.call(fbt) }
  rescue StandardError => e
    raise(e) unless e.message.include?('inside another transaction')
    once.call(fb)
  end
  [recent, born, previous]
end

# Give the interval marker back after the work failed, so it is tried again.
#
# @param [Factbase] fb The factbase to work with
# @param [String] marker The query that finds the marker of this judge
# @param [Boolean] born Whether the marker was created by the failed run
# @param [Time, nil] previous The timestamp the marker carried before the run
# @return [nil] Nothing
def Fbe.unclaim(fb, marker, born, previous)
  if born
    fb.query(marker).delete!
  elsif previous
    Fbe.overwrite(fb.query(marker).each.first, 'when', previous, fb:)
  end
  nil
end
