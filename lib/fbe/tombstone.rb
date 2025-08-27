# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'
require_relative 'if_absent'

# Checks whether an issue is already under a tombstone.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Tombstone
  # Ctor.
  # @param [Factbase] fb The factbase to use (defaults to Fbe.fb)
  def initialize(fb: Fbe.fb)
    @fb = fb
  end

  # Put it there.
  # @param [Integer] repo ID of repository
  # @param [Integer] issue ID of issue
  def bury!(repo, issue)
    f = @fb.query(
      "(and (eq what 'tombstone') (eq repository #{repo}) (exists issues))"
    ).each.first
    f =
      Fbe.if_absent(fb: @fb, always: true) do |n|
        n.what = 'tombstone'
        n.repository = repo
      end
    f.issues = "#{issue}-#{issue}"
  end

  # Is it there?
  # @param [Integer] repo ID of repository
  # @param [Integer] issue ID of issue
  # @return [Boolean] True if it's there
  def has?(repo, issue)
    f = @fb.query(
      "(and (eq what 'tombstone') (eq repository #{repo}) (exists issues))"
    ).each.first
    return false if f.nil?
    f['issues'].any? do |ii|
      a, b = ii.split('-')
      (a..b).include?(issue)
    end
  end
end