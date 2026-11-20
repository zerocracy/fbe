# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'sawyer'
require_relative '../fake_octokit'

# An answer of the fake.
#
# It is a +Sawyer::Resource+, the way a real answer is.
class Fbe::FakeOctokit::Answer < Sawyer::Resource
end
