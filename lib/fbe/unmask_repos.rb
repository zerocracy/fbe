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

require_relative 'octo'

# Unmask.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Zerocracy
# License:: MIT
module Fbe
  def self.mask_to_regex(mask)
    org, repo = mask.split('/')
    raise "Org '#{org}' can't have an asterisk" if org.include?('*')
    Regexp.compile("#{org}/#{repo.gsub('*', '.*')}")
  end

  def self.unmask_repos(options: $options, global: $global, loog: $loog)
    repos = []
    masks = (options.repositories || '').split(',')
    masks.reject { |m| m.start_with?('-') }.each do |mask|
      unless mask.include?('*')
        repos << mask
        next
      end
      re = Fbe.mask_to_regex(mask)
      Fbe.octo(loog:, global:, options:).repositories(mask.split('/')[0]).each do |r|
        repos << r[:full_name] if re.match?(r[:full_name])
      end
    end
    masks.select { |m| m.start_with?('-') }.each do |mask|
      re = Fbe.mask_to_regex(mask[1..])
      repos.reject! { |r| re.match?(r) }
    end
    loog.debug("Scanning #{repos.size} repositories: #{repos.join(', ')}...")
    repos
  end
end
