# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'

# Tells whether the fact carries exactly the times the attributes ask for.
#
# The match query renders a +Time+ with a second of precision, because
# +Factbase::Syntax+ cannot parse a fraction, so the candidates it returns
# must be compared to the original values here.
#
# @param [Factbase::Fact] fact The fact found by the query
# @param [Hash] attrs The attributes the caller asked for
# @return [Boolean] TRUE if every Time attribute is in the fact
def Fbe.same?(fact, attrs)
  attrs.all? { |k, v| !v.is_a?(Time) || [fact.public_send(k)].flatten.include?(v) }
end
