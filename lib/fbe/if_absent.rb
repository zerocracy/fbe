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

require 'others'
require 'time'
require_relative '../fbe'
require_relative 'fb'

# Injects a fact if it's absent in the factbase, otherwise (it is already
# there) returns NIL.
#
# Here is what you do when you want to add a fact to the factbase, but
# don't want to make a duplicate of an existing one:
#
#  require 'fbe/if_absent'
#  n =
#   Fbe.if_absent do |f|
#     f.what = 'something'
#     f.details = 'important'
#   end
#  return if n.nil?
#  n.when = Time.now
#
# This code will definitely create one fact with +what+ equals to +something+
# and +details+ equals to +important+, while the +when+ will be equal to the
# time of its first creation.
#
# @param [Factbase] fb The global factbase
# @yield [Factbase::Fact] The fact just created
# @return [nil|Factbase::Fact] Either +nil+ if it's already there or a new fact
def Fbe.if_absent(fb: Fbe.fb)
  attrs = {}
  f =
    others(map: attrs) do |*args|
      k = args[0]
      if k.end_with?('=')
        @map[k[0..-2].to_sym] = args[1]
      else
        @map[k.to_sym]
      end
    end
  yield f
  q = attrs.except('_id', '_time', '_version').map do |k, v|
    vv = v.to_s
    if v.is_a?(String)
      vv = "'#{vv.gsub('"', '\\\\"').gsub("'", "\\\\'")}'"
    elsif v.is_a?(Time)
      vv = v.utc.iso8601
    end
    "(eq #{k} #{vv})"
  end.join(' ')
  q = "(and #{q})"
  before = fb.query(q).each.to_a.first
  return nil if before
  n = fb.insert
  attrs.each { |k, v| n.send("#{k}=", v) }
  n
end
