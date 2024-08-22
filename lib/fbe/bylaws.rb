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

# A generator of policies/bylaws.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
def Fbe.bylaws(anger: 2, love: 2, paranoia: 2)
  raise 'The "anger" must be in the [0..4] interval' unless !anger.negative? && anger < 5
  raise 'The "lover" must be in the [0..4] interval' unless !love.negative? && love < 5
  raise 'The "paranoia" must be in the [1..4] interval' unless paranoia.positive? && paranoia < 5
  home = File.join(__dir__, '../../assets/bylaws')
  raise "The directory with templates is absent '#{home}'" unless File.exist?(home)
  Dir[File.join(home, '*.liquid')].to_h do |f|
    formula = Liquid::Template.parse(File.read(f)).render(
      'anger' => anger, 'love' => love, 'paranoia' => paranoia
    )
    [File.basename(f).gsub(/\.liquid$/, ''), formula]
  end
end
