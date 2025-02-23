# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'octo'

# Converts mask to repository name.
#
# This function takes something like +"zerocracy/*"+ as an input and returns
# a regular expression that may match repositories defined by this mask, which
# is +/zerocracy\/.*+ in this particular case.
#
# @param [String] mask The mask
# @return [Regex] Regular expression
def Fbe.mask_to_regex(mask)
  org, repo = mask.split('/')
  raise "Org '#{org}' can't have an asterisk" if org.include?('*')
  Regexp.compile("#{org}/#{repo.gsub('*', '.*')}")
end

# Builds a list of repositories required by the +repositories+ option.
#
# The +repositories+ option defined in the +$options+ must contain something
# like "zerocracy/fbe,zerocracy/ab*" (comma-separated list of masks). This
# function will go to the GitHub API and fetch all available repositories
# by these masks.
#
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Loog] loog The logging facility
# @return [Array<String>] List of repository full names
def Fbe.unmask_repos(options: $options, global: $global, loog: $loog)
  repos = []
  octo = Fbe.octo(loog:, global:, options:)
  masks = (options.repositories || '').split(',')
  masks.reject { |m| m.start_with?('-') }.each do |mask|
    unless mask.include?('*')
      repos << mask
      next
    end
    re = Fbe.mask_to_regex(mask)
    octo.repositories(mask.split('/')[0]).each do |r|
      repos << r[:full_name] if re.match?(r[:full_name])
    end
  end
  masks.select { |m| m.start_with?('-') }.each do |mask|
    re = Fbe.mask_to_regex(mask[1..])
    repos.reject! { |r| re.match?(r) }
  end
  repos.reject! { |repo| octo.repository(repo)[:archived] }
  raise "No repos found matching: #{options.repositories}" if repos.empty?
  repos.shuffle!
  loog.debug("Scanning #{repos.size} repositories: #{repos.join(', ')}...")
  repos
end
