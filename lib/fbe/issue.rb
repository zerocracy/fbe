# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'octo'

# Converts GitHub repository and issue IDs into a formatted issue reference.
#
# Takes the +repository+ and +issue+ properties from the provided +fact+,
# queries the GitHub API to get the repository's full name, and formats it
# as a standard GitHub issue reference (e.g., "zerocracy/fbe#42").
# Results are cached globally to minimize API calls.
#
# @param [Factbase::Fact] fact The fact containing repository and issue properties
# @param [Judges::Options] options The options from judges tool (uses $options global)
# @param [Hash] global The hash for global caching (uses $global)
# @param [Loog] loog The logging facility (uses $loog global)
# @return [String] Formatted issue reference (e.g., "owner/repo#123")
# @raise [RuntimeError] If fact is nil or required properties are missing
# @raise [RuntimeError] If required global variables are not set
# @note Requires 'repository' and 'issue' properties in the fact
# @note Repository names are cached to reduce GitHub API calls
# @example Format an issue reference
#   issue_fact = fb.query('(eq type "issue")').first
#   issue_fact.repository = 549866411  # Repository ID
#   issue_fact.issue = 42               # Issue number
#   puts Fbe.issue(issue_fact)  # => "zerocracy/fbe#42"
def Fbe.issue(fact, options: $options, global: $global, loog: $loog)
  raise 'The fact is nil' if fact.nil?
  raise 'The $global is not set' if global.nil?
  raise 'The $options is not set' if options.nil?
  raise 'The $loog is not set' if loog.nil?
  rid = fact['repository']
  raise "There is no 'repository' property" if rid.nil?
  rid = rid.first.to_i
  issue = fact['issue']
  raise "There is no 'issue' property" if issue.nil?
  issue = issue.first.to_i
  "#{Fbe.octo(global:, options:, loog:).repo_name_by_id(rid)}##{issue}"
end
