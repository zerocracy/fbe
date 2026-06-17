# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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
# @param [Time] epoch When the entire update started
# @param [Time] kickoff When the particular judge started
# @param [Boolean] lifetime_aware Check lifetime limitations (default: true)
# @param [Boolean] timeout_aware Check timeout limitations (default: true)
# @param [Boolean] quota_aware Check GitHub API quota (default: true)
# @yield [Factbase::Fact] The fact
def Fbe.consider(
  query,
  fb: Fbe.fb, judge: $judge, loog: $loog, options: $options, global: $global,
  epoch: $epoch || Time.now, kickoff: $kickoff || Time.now,
  lifetime_aware: true, timeout_aware: true, quota_aware: true, &
)
  Fbe.conclude(fb:, judge:, loog:, options:, global:, epoch:, kickoff:) do
    on(query)
    timeout_unaware unless timeout_aware
    lifetime_unaware unless lifetime_aware
    quota_unaware unless quota_aware
    consider(&)
  end
end
