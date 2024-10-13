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

require 'liquid'
require_relative '../fbe'

# Generates policies/bylaws.
#
# Using the templates stored in the +assets/bylaws+ directory, this function
# creates a hash, where keys are names and values are formulas of bylaws.
#
# @param [Integer] anger How strict must be the bylaws, giving punishments
# @param [Integer] love How big should be the volume of rewards
# @param [Integer] paranoia How much should be required to reward love
# @return [Hash<String, String>] Names of bylaws and their formulas
def Fbe.bylaws(anger: 2, love: 2, paranoia: 2)
  raise "The 'anger' must be in the [0..4] interval: #{anger.inspect}" unless !anger.negative? && anger < 5
  raise "The 'love' must be in the [0..4] interval: #{love.inspect}" unless !love.negative? && love < 5
  raise "The 'paranoia' must be in the [1..4] interval: #{paranoia.inspect}" unless paranoia.positive? && paranoia < 5
  home = File.join(__dir__, '../../assets/bylaws')
  raise "The directory with templates is absent #{home.inspect}" unless File.exist?(home)
  Dir[File.join(home, '*.liquid')].to_h do |f|
    formula = Liquid::Template.parse(File.read(f)).render(
      'anger' => anger, 'love' => love, 'paranoia' => paranoia
    )
    [File.basename(f).gsub(/\.liquid$/, ''), formula]
  end
end
