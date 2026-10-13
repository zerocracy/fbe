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
  raise(Fbe::Error, 'The $global is not set') if global.nil?
  raise(Fbe::Error, 'The $options is not set') if options.nil?
  raise(Fbe::Error, 'The $loog is not set') if loog.nil?
  if quota_aware
    octo = Fbe.octo(loog:, options:, global:)
    if octo.off_quota?(threshold: 100, resource: :core) ||
       octo.off_quota?(resource: :search, threshold: 10)
      loog.info('We are off GitHub quota, time to stop')
      return true
    end
  end
  if (lifetime_aware && options.lifetime) || (timeout_aware && options.timeout)
    wall_now = Time.now
    monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    starts = global[:fbe_monotonic_starts] ||= {}
    if lifetime_aware && options.lifetime
      epoch_start = starts[[:epoch, epoch]] ||= monotonic_now - (wall_now - epoch)
      if monotonic_now - epoch_start > options.lifetime * 0.9
        loog.info("We ran out of lifetime after #{(monotonic_now - epoch_start).round} seconds, must stop here")
        return true
      end
    end
    if timeout_aware && options.timeout
      kickoff_start = starts[[:kickoff, kickoff]] ||= monotonic_now - (wall_now - kickoff)
      if monotonic_now - kickoff_start > options.timeout * 0.9
        loog.info("We've spent #{(monotonic_now - kickoff_start).round} seconds, must stop here")
        return true
      end
    end
  end
  false
end
