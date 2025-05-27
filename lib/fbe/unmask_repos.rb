# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'octo'

# Converts a repository mask pattern to a regular expression.
#
# @example Basic wildcard matching
#   Fbe.mask_to_regex('zerocracy/*')
#   # => /zerocracy\/.*/i
#
# @example Specific repository (no wildcard)
#   Fbe.mask_to_regex('zerocracy/fbe')
#   # => /zerocracy\/fbe/i
#
# @param [String] mask Repository mask in format 'org/repo' where repo can contain '*'
# @return [Regexp] Case-insensitive regular expression for matching repositories
# @raise [RuntimeError] If organization part contains asterisk
def Fbe.mask_to_regex(mask)
  org, repo = mask.split('/')
  raise "Org '#{org}' can't have an asterisk" if org.include?('*')
  Regexp.compile("#{org}/#{repo.gsub('*', '.*')}", Regexp::IGNORECASE)
end

# Resolves repository masks to actual GitHub repository names.
#
# Takes a comma-separated list of repository masks from options and expands
# wildcards by querying GitHub API. Supports inclusion and exclusion patterns.
# Archived repositories are automatically filtered out.
#
# @example Basic usage with wildcards
#   # options.repositories = "zerocracy/fbe,zerocracy/ab*"
#   repos = Fbe.unmask_repos
#   # => ["zerocracy/fbe", "zerocracy/abc", "zerocracy/abcd"]
#
# @example Using exclusion patterns
#   # options.repositories = "zerocracy/*,-zerocracy/private*"
#   repos = Fbe.unmask_repos
#   # Returns all zerocracy repos except those starting with 'private'
#
# @example Empty result handling
#   # options.repositories = "nonexistent/*"
#   Fbe.unmask_repos  # Raises error: "No repos found matching: nonexistent/*"
#
# @param [Judges::Options] options Options containing 'repositories' field with masks
# @param [Hash] global Global cache for storing API responses
# @param [Loog] loog Logger for debug output
# @return [Array<String>] Shuffled list of repository full names (e.g., 'org/repo')
# @raise [RuntimeError] If no repositories match the provided masks
# @note Exclusion patterns must start with '-' (e.g., '-org/pattern*')
# @note Results are shuffled to distribute load when processing
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
