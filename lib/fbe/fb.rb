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

require 'loog'
require 'judges'
require 'factbase'
require 'factbase/looged'
require 'factbase/pre'
require 'factbase/rules'
require_relative '../fbe'

# Returns an instance of +Factbase+ (cached).
#
# Instead of using +$fb+ directly, it is recommended to use this utility
# method. It will not only return the global factbase, but will also
# make sure it's properly decorated and cached.
#
# @param [Factbase] fb The global factbase provided by the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @return [Factbase] The global factbase
def Fbe.fb(fb: $fb, global: $global, options: $options, loog: $loog)
  global[:fb] ||=
    begin
      rules = Dir.glob(File.join('rules', '*.fe')).map { |f| File.read(f) }
      fbe = Factbase::Rules.new(
        fb,
        "(and \n#{rules.join("\n")}\n)",
        uid: '_id'
      )
      fbe =
        Factbase::Pre.new(fbe) do |f, fbt|
          max = fbt.query('(eq _id (max _id))').each.to_a.first
          f._id = (max.nil? ? 0 : max._id) + 1
          f._time = Time.now
          f._version = "#{Factbase::VERSION}/#{Judges::VERSION}/#{options.action_version}"
          f._job = options.job_id unless options.job_id.nil?
        end
      Factbase::Looged.new(fbe, loog)
    end
end
