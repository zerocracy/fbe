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
require_relative 'octo'

# Converts an ID of GitHub user into a nicely formatting string with his name.
#
# The ID of the user (integer) is expected to be stored in the +who+ property of the
# provided +fact+. This function makes a live request to GitHub API in order
# to find out what is the name of the user. For example, the ID +526301+
# will be converted to the +"@yegor256"+ string.
#
# @param [Factbase::Fact] fact The fact, where to get the ID of GitHub user
# @param [String] prop The property in the fact, with the ID
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Loog] loog The logging facility
def Fbe.who(fact, prop = :who, options: $options, global: $global, loog: $loog)
  id = fact[prop.to_s]
  raise "There is no #{prop.inspect} property" if id.nil?
  id = id.first.to_i
  "@#{Fbe.octo(options:, global:, loog:).user_name_by_id(id)}"
end
