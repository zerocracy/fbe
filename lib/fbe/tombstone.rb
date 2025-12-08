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

  # See all issues in the tombstone, as array of numbers.
  # @param [String] where The place, e.g. "github"
  # @param [Integer] repo ID of repository
  # @return [Array<Integer>] IDs of issue
  def issues(where, repo)
    raise 'The type of "where" is not String' unless where.is_a?(String)
    raise 'The type of "repo" is not Integer' unless repo.is_a?(Integer)
    f = @fb.query(
      "(and (eq where '#{where}') (eq what 'tombstone') (eq repository #{repo}) (exists issues))"
    ).each.first
    return [] if f.nil?
    f['issues'].map do |ii|
      a, b = ii.split('-').map(&:to_i)
      b = a if b.nil?
      (a..b).map { |i| i }
    end.flatten
  end

  # Put it there.
  # @param [String] where The place, e.g. "github"
  # @param [Integer] repo ID of repository
  # @param [Integer, Array<Integer>] issue ID of issue (or array of them)
  def bury!(where, repo, issue)
    raise 'The type of "where" is not String' unless where.is_a?(String)
    raise 'The type of "repo" is not Integer' unless repo.is_a?(Integer)
    raise 'The type of "issue" is neither Integer nor Array' unless issue.is_a?(Integer) || issue.is_a?(Array)
    f =
      Fbe.if_absent(fb: @fb, always: true) do |n|
        n.what = 'tombstone'
        n.where = where
        n.repository = repo
      end
    f.send(:"#{@fid}=", SecureRandom.random_number(99_999)) if f[@fid].nil?
    nn = f['issues']&.map { |ii| ii.split('-').map(&:to_i).then { |ii| ii.size == 1 ? ii << ii[0] : ii } } || []
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
    Fbe.overwrite(
      f, 'issues', merged.map { |ii| ii[0] == ii[1] ? ii[0].to_s : "#{ii[0]}-#{ii[1]}" },
      fb: @fb, fid: @fid
    )
  end

  # Is it there?
  # @param [String] where The place, e.g. "github"
  # @param [Integer] repo ID of repository
  # @param [Integer, Array<Integer>] issue ID of issue (or array of them)
  # @return [Boolean] True if it's there
  def has?(where, repo, issue)
    raise 'The type of "where" is not String' unless where.is_a?(String)
    raise 'The type of "repo" is not Integer' unless repo.is_a?(Integer)
    raise 'The type of "issue" is neither Integer nor Array' unless issue.is_a?(Integer) || issue.is_a?(Array)
    f = @fb.query(
      "(and (eq where '#{where}') (eq what 'tombstone') (eq repository #{repo}) (exists issues))"
    ).each.first
    return false if f.nil?
    issue = [issue] unless issue.is_a?(Array)
    issue.all? do |i|
      f['issues'].any? do |ii|
        a, b = ii.split('-').map(&:to_i)
        b.nil? ? a == i : (a..b).cover?(i)
      end
    end
  end
end
