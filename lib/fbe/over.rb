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
  if lifetime_aware && !options.lifetime.nil?
    lifetime =
      begin
        Integer(options.lifetime)
      rescue ArgumentError, TypeError
        raise(Fbe::Error, "The lifetime option (#{options.lifetime.inspect}) is not an Integer")
      end
    raise(Fbe::Error, "The lifetime option must be a positive Integer, got #{lifetime}") unless lifetime.positive?
    if Time.now - epoch > lifetime * 0.9
      loog.info("We ran out of lifetime (#{epoch.ago} already), must stop here")
      return true
    end
  end
  if timeout_aware && !options.timeout.nil?
    timeout =
      begin
        Integer(options.timeout)
      rescue ArgumentError, TypeError
        raise(Fbe::Error, "The timeout option (#{options.timeout.inspect}) is not an Integer")
      end
    raise(Fbe::Error, "The timeout option must be a positive Integer, got #{timeout}") unless timeout.positive?
    if Time.now - kickoff > timeout * 0.9
      loog.info("We've spent more than #{kickoff.ago}, must stop here")
      return true
    end
  end
  false
end
