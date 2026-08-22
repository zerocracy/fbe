# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Delete a few facts, knowing their IDs.
#
# @param [Array] facts List of facts to kill
# @param [Factbase] fb The factbase to use (defaults to Fbe.fb)
# @param [String] fid The name of the property that holds the ID (defaults to '_id')
# @raise [Fbe::Error] If a fact does not have the +fid+ property
def Fbe.kill_if(facts, fb: Fbe.fb, fid: '_id')
  ids = []
  facts.each do |f|
    if block_given?
      t = yield(f)
      next unless t
    end
    id = f[fid]&.first
    raise(Fbe::Error, "There is no #{fid} in the fact, cannot use Fbe.kill_if") if id.nil?
    ids << id
  end
  return 0 if ids.empty?
  fb.query("(or #{ids.map { |id| "(eq #{fid} #{id})" }.join(' ')})").delete!
end
