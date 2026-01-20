# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# The main and only module of this gem.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
module Fbe
  # Current version of the gem (changed by +.rultor.yml+ on every release)
  VERSION = '0.48.2' unless const_defined?(:VERSION)
end
