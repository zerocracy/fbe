# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'
require_relative 'if_absent'
require_relative 'overwrite'

# Checks whether an issue is already under a tombstone.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2025 Zerocracy
# License:: MIT
class Fbe::Tombstone
  # Ctor.
  # @param [Factbase] fb The factbase to use (defaults to Fbe.fb)
  def initialize(fb: Fbe.fb, fid: '_id')
    @fb = fb
    @fid = fid
  end

  # Put it there.
  # @param [Integer] repo ID of repository
  # @param [Integer] issue ID of issue
  def bury!(repo, issue)
    f =
      Fbe.if_absent(fb: @fb, always: true) do |n|
        n.what = 'tombstone'
        n.repository = repo
      end
    f.send(:"#{@fid}=", SecureRandom.random_number(99_999)) if f[@fid].nil?
    nn = f['issues']&.map { |ii| ii.split('-').map(&:to_i) } || []
    nn << [issue, issue]
    nn = nn.sort_by(&:first)
    merged = []
    nn.each do |a, b|
      if merged.empty?
        merged << [a, b]
      else
        last = merged[-1]
        if last[1] == a - 1
          last[1] = b
        else
          merged << [a, b]
        end
      end
    end
    Fbe.overwrite(f, 'issues', merged.map { |ii| "#{ii[0]}-#{ii[1]}" }, fb: @fb, fid: @fid)
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
      a, b = ii.split('-').map(&:to_i)
      (a..b).cover?(issue)
    end
  end
end
