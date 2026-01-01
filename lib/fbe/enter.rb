# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'baza-rb'
require_relative '../fbe'

# Enter a new valve in the Zerocracy system.
#
# A valve is a checkpoint or gate in the processing pipeline. This method
# records the entry into a valve with a reason, unless in testing mode.
#
# @param [String] badge Unique badge identifier for the valve
# @param [String] why The reason for entering this valve
# @param [Judges::Options] options The options from judges tool (uses $options if not provided)
# @param [Loog] loog The logging facility (uses $loog if not provided)
# @yield Block to execute within the valve context
# @return [Object] The result of the yielded block
# @raise [RuntimeError] If badge, why, or required globals are nil
# @note Requires $options and $loog global variables to be set
# @note In testing mode (options.testing != nil), bypasses valve recording
# @example Enter a valve for processing
#   Fbe.enter('payment-check', 'Validating payment data') do
#     # Process payment validation
#     validate_payment(data)
#   end
def Fbe.enter(badge, why, options: $options, loog: $loog, &)
  raise 'The badge is nil' if badge.nil?
  raise 'The why is nil' if why.nil?
  raise 'The $options is not set' if options.nil?
  raise 'The $loog is not set' if loog.nil?
  return yield unless options.testing.nil?
  baza = BazaRb.new('api.zerocracy.com', 443, options.zerocracy_token, loog:)
  baza.enter(options.job_name, badge, why, options.job_id.to_i, &)
end
