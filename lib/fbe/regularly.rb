# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tago'
require_relative '../fbe'
require_relative 'fb'

# Run the block provided every X days based on PMP configuration.
#
# Executes a block periodically based on PMP (Project Management Plan) settings.
# The block will only run if it hasn't been executed within the specified interval.
# Creates a fact recording when the judge was last run.
#
# @param [String] area The name of the PMP area
# @param [String] p_every_days PMP property name for interval (defaults to 7 days if not in PMP)
# @param [String] p_since_days PMP property name for since period (defaults to 28 days if not in PMP)
# @param [Factbase] fb The factbase (defaults to Fbe.fb)
# @param [String] judge The name of the judge (uses $judge global)
# @param [Loog] loog The logging facility (uses $loog global)
# @yield [Factbase::Fact] Fact to populate with judge execution details
# @return [nil] Nothing
# @raise [RuntimeError] If required parameters or globals are nil
# @note Skips execution if judge was run within the interval period
# @note The 'since' property is added to the fact when p_since_days is provided
# @example Run a cleanup task every 3 days
#   Fbe.regularly('cleanup', 'days_between_cleanups', 'cleanup_history_days') do |f|
#     f.total_cleaned = cleanup_old_records
#     # PMP might have: days_between_cleanups=3, cleanup_history_days=30
#   end
def Fbe.regularly(area, p_every_days, p_since_days = nil, fb: Fbe.fb, judge: $judge, loog: $loog, &)
  raise 'The area is nil' if area.nil?
  raise 'The p_every_days is nil' if p_every_days.nil?
  raise 'The fb is nil' if fb.nil?
  raise 'The $judge is not set' if judge.nil?
  raise 'The $loog is not set' if loog.nil?
  pmp = fb.query("(and (eq what 'pmp') (eq area '#{area}') (exists #{p_every_days}))").each.first
  interval = pmp.nil? ? 7 : pmp[p_every_days].first
  recent = fb.query(
    "(and
      (eq what '#{judge}')
      (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '#{interval} days')))"
  ).each.first
  if recent
    loog.info(
      "#{$judge} statistics were collected #{recent.when.ago} ago, " \
      "skipping now (we run it every #{interval} days)"
    )
    return
  end
  loog.info("#{$judge} statistics weren't collected for the last #{interval} days")
  fb.txn do |fbt|
    f = fbt.insert
    f.what = judge
    f.when = Time.now
    unless p_since_days.nil?
      days = pmp.nil? ? 28 : pmp[p_since_days].first
      since = Time.now - (days * 24 * 60 * 60)
      f.since = since
    end
    yield f
  end
  nil
end
