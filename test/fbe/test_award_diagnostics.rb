# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/fbe/award'
require_relative '../test__helper'

class TestAwardDiagnostics < Fbe::Test
  def test_identifies_the_failing_bill_term
    award = Fbe::Award.new('(award (give (plus x y) "a contribution"))')
    error = assert_raises(Fbe::Error) { award.bill({}) }
    assert_includes(error.message, 'Failure in (give (plus x y) a contribution)')
  end

  def test_identifies_the_failing_nested_bill_term
    award = Fbe::Award.new('(award (aka (give (plus x y) "a contribution") "a rule"))')
    error = assert_raises(Fbe::Error) { award.bill({}) }
    assert_includes(error.message, 'Failure in (aka')
    assert_includes(error.message, 'Failure in (give')
  end

  def test_identifies_the_failing_bylaw_term
    award = Fbe::Award.new('(award (unknown 1))')
    error = assert_raises(Fbe::Error) { award.bylaw }
    assert_includes(error.message, 'Failure in (unknown 1)')
  end

  def test_identifies_the_failing_nested_bylaw_term
    award = Fbe::Award.new('(award (aka (unknown 1) "a rule"))')
    error = assert_raises(Fbe::Error) { award.bylaw }
    assert_includes(error.message, 'Failure in (aka')
    assert_includes(error.message, 'Failure in (unknown 1)')
  end

  def test_evaluates_every_operand_of_and
    award = Fbe::Award.new('(award (give (if (and (eq x 1) (eq x 1) (eq x 2)) 5 0) "a contribution"))')
    assert_equal(0, award.bill({ x: 1 }).points)
  end

  def test_renders_comparisons_and_a_minimum
    {
      '(if (lte a b) 1 0)' => '_a_ ≤ _b_',
      '(if (gte a b) 1 0)' => '_a_ ≥ _b_',
      '(min a b)' => 'minimum of _a_ and _b_'
    }.each do |expression, expected|
      award = Fbe::Award.new("(award (give #{expression} \"a contribution\"))")
      assert_includes(award.bylaw.markdown, expected, expression)
    end
  end

  def test_formats_fractional_literals_as_numbers
    award = Fbe::Award.new('(award (give (times x 0.5) "a contribution"))')
    assert_includes(award.bylaw.markdown, '_x_ × **0.5**')
  end

  def test_joins_a_fractional_assignment_with_its_award
    award = Fbe::Award.new('(award (set b (times x 0.5)) (give b "a contribution"))')
    assert_includes(award.bylaw.markdown, 'set _b_ to _x_ × **0.5**, and award _b_.')
  end
end
