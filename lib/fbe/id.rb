# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'

# Converts a value used as a GitHub identifier to an integer without rounding.
#
# @param [Object] value The identifier value stored in the fact
# @param [String] property A human-readable property label for error messages
# @return [Integer] The exact identifier
# @raise [Fbe::Error] If the value is not a whole, safely represented identifier
def Fbe.whole_id(value, property)
  case value
  when Integer
    value
  when Float
    unless value.finite? && value.frac.zero? && value.abs <= ((2**53) - 1)
      raise(ArgumentError)
    end
    value.to_i
  when String
    begin
      Integer(value, 10)
    rescue ArgumentError
      number = Float(value)
      unless number.finite? && number.frac.zero? && number.abs <= ((2**53) - 1)
        raise(ArgumentError)
      end
      number.to_i
    end
  else
    number = Integer(value)
    raise(ArgumentError) unless number == value
    number
  end
rescue ArgumentError, TypeError, RangeError
  raise(Fbe::Error, "The #{property} (#{value.inspect}) must be an integer ID")
end
