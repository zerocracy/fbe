# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'sawyer'
require_relative '../fake_octokit'

# An answer of the fake.
#
# It is a +Sawyer::Resource+, the way a real answer is, and it also takes
# part in pattern matching, which the tests of this gem lean on.
class Fbe::FakeOctokit::Answer < Sawyer::Resource
  # Gives the keys asked for, so that the answer can be matched by pattern.
  #
  # @param [Array<Symbol>, nil] keys The keys wanted, or nil for all of them
  # @return [Hash] The values under those keys
  def deconstruct_keys(keys) # rubocop:disable Elegant/GoodMethodName
    h = to_attrs
    keys.nil? ? h : h.slice(*keys)
  end

  # Compares by the attributes, the way a hash compares.
  #
  # Two answers built from the same hash are two objects, and a test that
  # puts one method of the fake against another one has to see them as
  # equal, the way it saw the two hashes that used to come back.
  #
  # @param [Object] other The other one
  # @return [Boolean] TRUE if they carry the same attributes
  def ==(other) # rubocop:disable Elegant/GoodMethodName
    case other
    when Fbe::FakeOctokit::Answer
      to_attrs == other.to_attrs
    when Hash
      to_attrs == other
    else
      super
    end
  end

  # Gives the names of the attributes, the way a hash gives them.
  #
  # @return [Array<Symbol>] The names
  def keys
    to_attrs.keys
  end
end
