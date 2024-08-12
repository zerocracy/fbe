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
require_relative 'overwrite'

# Run the block provided every X hours.
#
# @param [String] area The name of the PMP area
# @param [Integer] p_every_hours How frequently to run, every X hours
def Fbe.repeatedly(area, p_every_hours, fb: Fbe.fb, judge: $judge, loog: $loog, &)
  pmp = fb.query("(and (eq what 'pmp') (eq area '#{area}') (exists #{p_every_hours}))").each.to_a.first
  hours = pmp.nil? ? 24 : pmp[p_every_hours].first
  unless fb.query(
    "(and
      (eq what '#{judge}')
      (gt when (minus (to_time (env 'TODAY' '#{Time.now.utc.iso8601}')) '#{hours} hours')))"
  ).each.to_a.empty?
    loog.debug("#{$judge} have recently been executed, skipping now")
    return
  end
  f = fb.query("(and (eq what '#{judge}'))").each.to_a.first
  if f.nil?
    f = fb.insert
    f.what = judge
  end
  Fbe.overwrite(f, 'when', Time.now)
  yield fb.query("(and (eq what '#{judge}'))").each.to_a.first
end
