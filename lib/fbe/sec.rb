# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024-2025 Zerocracy
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

# Converts number of seconds into text.
#
# THe number of seconds is taken from the +fact+ provided, usually stored
# there in the +seconds+ property. The seconds are formatted to hours,
# days, or weeks.
#
# @param [Factbase::Fact] fact The fact, where to get the number of seconds
# @param [String] prop The property in the fact, with the seconds
# @return [String] Time interval as a text
def Fbe.sec(fact, prop = :seconds)
  s = fact[prop.to_s]
  raise "There is no #{prop.inspect} property" if s.nil?
  s = s.first.to_i
  if s < 60
    format('%d seconds', s)
  elsif s < 60 * 60
    format('%d minutes', s / 60)
  elsif s < 60 * 60 * 24
    format('%d hours', s / (60 * 60))
  elsif s < 7 * 60 * 60 * 24
    format('%d days', s / (60 * 60 * 24))
  else
    format('%d weeks', s / (7 * 60 * 60 * 24))
  end
end
