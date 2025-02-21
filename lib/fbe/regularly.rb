# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Run the block provided every X days.
#
# @param [String] area The name of the PMP area
# @param [Integer] p_every_days How frequently to run, every X days
# @param [Integer] p_since_days Since when to collect stats, X days
# @param [Factbase] fb The factbase
# @param [String] judge The name of the judge, from the +judges+ tool
# @param [Loog] loog The logging facility
# @return [nil] Nothing
def Fbe.regularly(area, p_every_days, p_since_days = nil, fb: Fbe.fb, judge: $judge, loog: $loog, &)
  pmp = fb.query("(and (eq what 'pmp') (eq area '#{area}') (exists #{p_every_days}))").each.to_a.first
  interval = pmp.nil? ? 7 : pmp[p_every_days].first
  unless fb.query(
    "(and
      (eq what '#{judge}')
      (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '#{interval} days')))"
  ).each.to_a.empty?
    loog.debug("#{$judge} statistics have recently been collected, skipping now")
    return
  end
  f = fb.insert
  f.what = judge
  f.when = Time.now
  unless p_since_days.nil?
    days = pmp.nil? ? 28 : pmp[p_since_days].first
    since = Time.now - (days * 24 * 60 * 60)
    f.since = since
  end
  yield f
  nil
end
