# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

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
# @return [String] Full name of the user
def Fbe.who(fact, prop = :who, options: $options, global: $global, loog: $loog)
  id = fact[prop.to_s]
  raise "There is no #{prop.inspect} property" if id.nil?
  id = id.first.to_i
  "@#{Fbe.octo(options:, global:, loog:).user_name_by_id(id)}"
end
