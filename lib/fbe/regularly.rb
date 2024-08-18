# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require_relative '../fbe'
require_relative 'fb'

# Run the block provided every X days.
#
# @param [String] area The name of the PMP area
# @param [Integer] p_every_days How frequently to run, every X days
# @param [Integer] p_since_days Since when to collect stats, X days
# @param [Factbase] fb The factbase
# @param [String] judge The name of the judge, from the +judges+ tool
# @param [Loog] logg The logging facility
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
end
