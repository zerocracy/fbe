# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'
require_relative 'fb'

# Delete a few facts, knowing their IDs.
#
# @param [Array] facts List of facts to kill
# @param [Factbase] fb The factbase to use (defaults to Fbe.fb)
def Fbe.kill_if(facts, fb: Fbe.fb, fid: '_id')
  ids = []
  facts.each do |f|
    if block_given?
      t = yield f
      next unless t
    end
    ids << f[fid].first
  end
  fb.query("(or #{ids.map { |id| "(eq #{fid} #{id})" }.join})").delete!
end
