# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'
require_relative 'overwrite'

# Run the block provided every X hours.
#
# @param [String] area The name of the PMP area
# @param [Integer] p_every_hours How frequently to run, every X hours
# @param [Factbase] fb The factbase
# @param [String] judge The name of the judge, from the +judges+ tool
# @param [Loog] loog The logging facility
# @return [nil] Nothing
def Fbe.repeatedly(area, p_every_hours, fb: Fbe.fb, judge: $judge, loog: $loog, &)
  raise 'The area is nil' if area.nil?
  raise 'The p_every_hours is nil' if p_every_hours.nil?
  raise 'The fb is nil' if fb.nil?
  raise 'The $judge is not set' if judge.nil?
  raise 'The $loog is not set' if loog.nil?
  pmp = fb.query("(and (eq what 'pmp') (eq area '#{area}') (exists #{p_every_hours}))").each.to_a.first
  hours = pmp.nil? ? 24 : pmp[p_every_hours].first
  unless fb.query(
    "(and
      (eq what '#{judge}')
      (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '#{hours} hours')))"
  ).each.to_a.empty?
    loog.debug("#{$judge} has recently been executed, skipping now")
    return
  end
  f = fb.query("(and (eq what '#{judge}'))").each.to_a.first
  if f.nil?
    f = fb.insert
    f.what = judge
  end
  Fbe.overwrite(f, 'when', Time.now)
  yield fb.query("(and (eq what '#{judge}'))").each.to_a.first
  nil
end
