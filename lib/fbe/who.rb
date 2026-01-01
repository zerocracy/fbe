# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'octo'

# Converts a GitHub user ID into a formatted username string.
#
# The ID of the user (integer) is expected to be stored in the +who+ property of the
# provided +fact+. This function makes a live request to GitHub API to
# retrieve the username. The result is cached globally to minimize API calls.
# For example, the ID +526301+ will be converted to +"@yegor256"+.
#
# @param [Factbase::Fact] fact The fact containing the GitHub user ID
# @param [String, Symbol] prop The property name with the ID (defaults to :who)
# @param [Judges::Options] options The options from judges tool (uses $options global)
# @param [Hash] global The hash for global caching (uses $global)
# @param [Loog] loog The logging facility (uses $loog global)
# @return [String] Formatted username with @ prefix (e.g., "@yegor256")
# @raise [RuntimeError] If the specified property doesn't exist in the fact
# @note Results are cached to reduce GitHub API calls
# @note Subject to GitHub API rate limits
# @example Convert user ID to username
#   contributor = fb.query('(eq type "contributor")').first
#   contributor.author_id = 526301
#   puts Fbe.who(contributor, :author_id)  # => "@yegor256"
def Fbe.who(fact, prop = :who, options: $options, global: $global, loog: $loog)
  id = fact[prop.to_s]
  raise "There is no #{prop.inspect} property" if id.nil?
  id = id.first.to_i
  "@#{Fbe.octo(options:, global:, loog:).user_name_by_id(id)}"
end
