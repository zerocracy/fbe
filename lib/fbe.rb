# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# The main and only module of this gem.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
module Fbe
  VERSION = '0.0.0' unless const_defined?(:VERSION)
  class Error < StandardError; end
end

# Removes the _id property from the fact's internal map, so the recreation
# loop can restore the original _id from the deleted fact. This is needed
# because the +Factbase::Pre+ hook sets _id before the loop runs.
def Fbe.unid(fact)
  f = fact
  while f.instance_variable_defined?(:@fact) || f.instance_variable_defined?(:@origin)
    iv = f.instance_variable_defined?(:@fact) ? :@fact : :@origin
    f = f.instance_variable_get(iv)
  end
  f.instance_variable_get(:@map).delete('_id')
end
