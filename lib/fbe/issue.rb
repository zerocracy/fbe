# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'octo'

# Converts an ID of GitHub issue into a nicely formatting string.
#
# The function takes the +repository+ property of the provided +fact+,
# goes to the GitHub API in order to find the full name of the repository,
# and then creates a string with the full name of repository + issue, for
# example +"zerocracy/fbe#42"+.
#
# @param [Factbase::Fact] fact The fact, where to get the ID of GitHub issue
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Loog] loog The logging facility
# @return [String] Textual representation of GitHub issue number
def Fbe.issue(fact, options: $options, global: $global, loog: $loog)
  rid = fact['repository']
  raise "There is no 'repository' property" if rid.nil?
  rid = rid.first.to_i
  issue = fact['issue']
  raise "There is no 'issue' property" if issue.nil?
  issue = issue.first.to_i
  "#{Fbe.octo(global:, options:, loog:).repo_name_by_id(rid)}##{issue}"
end
