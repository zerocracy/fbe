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

# Converts an ID of GitHub user into a nicely formatting string with his name.
#
# @param [Factbase::Fact] fact The fact, where to get the ID of GitHub user
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Loog] logg The logging facility
def Fbe.issue(fact, options: $options, global: $global, loog: $loog)
  rid = fact['repository']
  raise "There is no 'repository' property" if rid.nil?
  rid = rid.first.to_i
  issue = fact['issue']
  raise "There is no 'issue' property" if issue.nil?
  issue = issue.first.to_i
  "#{Fbe.octo(global:, options:, loog:).repo_name_by_id(rid)}##{issue}"
end
