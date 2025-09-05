# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'securerandom'
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
  # @param [String] where The place, e.g. "github"
  # @param [Integer] repo ID of repository
  # @param [Integer] issue ID of issue (or array of them)
  def bury!(where, repo, issue)
    f =
      Fbe.if_absent(fb: @fb, always: true) do |n|
        n.what = 'tombstone'
        n.where = where
        n.repo = repo
      end
    f.send(:"#{@fid}=", SecureRandom.random_number(99_999)) if f[@fid].nil?
    nn = f['issues']&.map { |ii| ii.split('-').map(&:to_i) } || []
    issue = [issue] unless issue.is_a?(Array)
    issue.each do |i|
      nn << [i, i]
    end
    merged =
      nn.sort.each_with_object([]) do |(a, b), merged|
        if !merged.empty? && merged[-1][0] <= a && a <= merged[-1][1] + 1
          merged[-1][1] = b if b > merged[-1][1]
        else
          merged << [a, b]
        end
      end
    Fbe.overwrite(f, 'issues', merged.map { |ii| "#{ii[0]}-#{ii[1]}" }, fb: @fb, fid: @fid)
  end

  # Is it there?
  # @param [String] where The place, e.g. "github"
  # @param [Integer] repo ID of repository
  # @param [Integer] issue ID of issue (or array of them)
  # @return [Boolean] True if it's there
  def has?(where, repo, issue)
    f = @fb.query(
      "(and (eq where '#{where}') (eq what 'tombstone') (eq repo #{repo}) (exists issues))"
    ).each.first
    return false if f.nil?
    issue = [issue] unless issue.is_a?(Array)
    issue.all? do |i|
      f['issues'].any? do |ii|
        a, b = ii.split('-').map(&:to_i)
        (a..b).cover?(i)
      end
    end
  end
end
