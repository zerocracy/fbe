# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'baza-rb'
require_relative '../fbe'

# Enter a new valve.
#
# @param [String] badge Unique badge of the valve
# @param [String] why The reason
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @return [String] Full name of the user
def Fbe.enter(badge, why, options: $options, loog: $loog, &)
  return yield unless options.testing.nil?
  baza = BazaRb.new('api.zerocracy.com', 443, options.zerocracy_token, loog:)
  baza.enter(options.job_name, badge, why, options.job_id.to_i, &)
end
