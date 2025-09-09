# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'conclude'
require_relative 'fb'

# Creates an instance of {Fbe::Conclude} and then runs "consider" in it.
#
# @param [String] query The query
# @param [Factbase] fb The factbase
# @param [String] judge The name of the judge, from the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @yield [Factbase::Fact] The fact
def Fbe.consider(
  query,
  fb: Fbe.fb, judge: $judge, loog: $loog, options: $options, global: $global,
  start: $start, &
)
  Fbe.conclude(fb:, judge:, loog:, options:, global:, start:) do
    on query
    consider(&)
  end
end
