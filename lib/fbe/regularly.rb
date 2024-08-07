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

def Fbe.regularly(area, days, interval, fb: Fbe.fb, judge: $judge, loog: $loog, &)
  pmp = fb.query("(and (eq what 'pmp') (eq area '#{area}') (exists #{days}))").each.to_a.first
  days = pmp.nil? ? 28 : pmp[days].first
  since = Time.now - (days * 24 * 60 * 60)
  interval = pmp.nil? ? 7 : pmp[interval].first
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
  f.since = since
  yield f
end
