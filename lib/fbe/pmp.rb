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
require_relative 'fb'
require_relative '../fbe'

# Get configuration parameter from the "PMP" fact.
#
# @param [Factbase] fb The factbase
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] logg The logging facility
def Fbe.pmp(fb: Fbe.fb, global: $global, options: $options, loog: $loog)
  others do |*args1|
    area = args1.first
    others do |*args2|
      param = args2.first
      f = Fbe.fb(global:, fb:, options:, loog:).query("(and (eq what 'pmp') (eq area '#{area}'))").each.to_a.first
      raise "Unknown area '#{area}'" if f.nil?
      r = f[param]
      raise "Unknown property '#{param}' in the '#{area}' area" if r.nil?
      r.first
    end
  end
end
