# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/id'
require_relative '../test__helper'

# Exact conversion of identifiers stored as different numeric types.
class TestId < Fbe::Test
  def test_accepts_whole_float
    assert_equal(42, Fbe.whole_id(42.0, 'identifier'))
  end

  def test_accepts_integer_string_without_losing_precision
    assert_equal((2**53) + 1, Fbe.whole_id(((2**53) + 1).to_s, 'identifier'))
  end

  def test_accepts_decimal_string_with_a_whole_value
    assert_equal(42, Fbe.whole_id('42.0', 'identifier'))
  end

  def test_rejects_fractional_decimal_string
    assert_raises(Fbe::Error) { Fbe.whole_id('42.5', 'identifier') }
  end

  def test_accepts_exact_rational
    assert_equal(42, Fbe.whole_id(Rational(84, 2), 'identifier'))
  end

  def test_rejects_fractional_rational
    assert_raises(Fbe::Error) { Fbe.whole_id(Rational(85, 2), 'identifier') }
  end
end
