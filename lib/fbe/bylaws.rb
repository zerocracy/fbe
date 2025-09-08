# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'liquid'
require_relative '../fbe'

# Generates policies/bylaws from Liquid templates.
#
# Using the templates stored in the +assets/bylaws+ directory, this function
# creates a hash where keys are bylaw names (derived from filenames) and values
# are the rendered formulas. Templates can use three parameters to control
# the strictness and generosity of the bylaws.
#
# @param [Integer] anger Strictness level for punishments (0-4, default: 2)
#   - 0: Very lenient, minimal punishments
#   - 2: Balanced approach (default)
#   - 4: Very strict, maximum punishments
# @param [Integer] love Generosity level for rewards (0-4, default: 2)
#   - 0: Minimal rewards
#   - 2: Balanced rewards (default)
#   - 4: Maximum rewards
# @param [Integer] paranoia Requirements threshold for rewards (1-4, default: 2)
#   - 1: Easy to earn rewards
#   - 2: Balanced requirements (default)
#   - 4: Very difficult to earn rewards
# @return [Hash<String, String>] Hash mapping bylaw names to their formulas
# @raise [RuntimeError] If parameters are out of valid ranges
# @example Generate balanced bylaws
#   bylaws = Fbe.bylaws(anger: 2, love: 2, paranoia: 2)
#   bylaws['bug-report-was-rewarded']
#   # => "award { 2 * love * paranoia }"
# @example Generate strict bylaws with minimal rewards
#   bylaws = Fbe.bylaws(anger: 4, love: 1, paranoia: 3)
#   bylaws['dud-was-punished']
#   # => "award { -16 * anger }"
def Fbe.bylaws(anger: 2, love: 2, paranoia: 2)
  raise "The 'anger' must be in the [0..4] interval: #{anger.inspect}" unless !anger.negative? && anger < 5
  raise "The 'love' must be in the [0..4] interval: #{love.inspect}" unless !love.negative? && love < 5
  raise "The 'paranoia' must be in the [1..4] interval: #{paranoia.inspect}" unless paranoia.positive? && paranoia < 5
  home = File.join(__dir__, '../../assets/bylaws')
  raise "The directory with templates is absent #{home.inspect}" unless File.exist?(home)
  Dir[File.join(home, '*.fe.liquid')].to_h do |f|
    formula = Liquid::Template.parse(File.read(f)).render(
      'anger' => anger, 'love' => love, 'paranoia' => paranoia
    )
    [File.basename(f).gsub(/\.fe.liquid$/, ''), formula]
  end
end
