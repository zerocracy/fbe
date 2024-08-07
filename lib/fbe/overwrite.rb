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

# Overwrite a property in the fact.
#
# If the property doesn't exist in the fact, it will be added. If it does
# exist, it will be removed (the entire fact will be destroyed, new fact
# created, and property set).
#
# @param [Factbase::Fact] fact The fact to modify
# @param [String] property The name of the property to set
# @param [Any] vqlue The value to set
def Fbe.overwrite(fact, property, value, fb: Fbe.fb)
  before = {}
  fact.all_properties.each do |prop|
    before[prop.to_s] = fact[prop]
  end
  fb.query("(and #{before.map { |k, vv| vv.is_a?(Array) ? '' : " (eq #{k} #{vv})" }.join})").delete!
  n = fb.insert
  before[property.to_s] = value
  before.each do |k, vv|
    next if k.start_with?('_')
    vv = [vv] unless vv.is_a?(Array)
    vv.each do |v|
      n.send("#{k}=", v)
    end
  end
end
