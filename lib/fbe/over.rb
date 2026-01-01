# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'octo'

# Check GitHub API quota, lifetime, and timeout.
#
# @param [Hash] global Hash of global options
# @param [Judges::Options] options The options available globally
# @param [Loog] loog Logging facility
# @param [Time] epoch When the entire update started
# @param [Time] kickoff When the particular judge started
# @param [Boolean] quota_aware Enable or disable check of GitHub API quota
# @param [Boolean] lifetime_aware Enable or disable check of lifetime limitations
# @param [Boolean] timeout_aware Enable or disable check of timeout limitations
# @return [Boolean] check result
def Fbe.over?(
  global: $global, options: $options, loog: $loog,
  epoch: $epoch || Time.now, kickoff: $kickoff || Time.now,
  quota_aware: true, lifetime_aware: true, timeout_aware: true
)
  if quota_aware && Fbe.octo(loog:, options:, global:).off_quota?(threshold: 100)
    loog.info('We are off GitHub quota, time to stop')
    return true
  end
  if lifetime_aware && options.lifetime && Time.now - epoch > options.lifetime * 0.9
    loog.info("We ran out of lifetime (#{epoch.ago} already), must stop here")
    return true
  end
  if timeout_aware && options.timeout && Time.now - kickoff > options.timeout * 0.9
    loog.info("We've spent more than #{kickoff.ago}, must stop here")
    return true
  end
  false
end
