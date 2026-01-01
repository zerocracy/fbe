# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fbe'

# Middleware components for Faraday HTTP client configuration.
#
# This module serves as a namespace for various middleware components
# that enhance Faraday HTTP client functionality with custom behaviors
# such as request/response formatting, logging, and error handling.
#
# The middleware components in this module are designed to work with
# the Faraday HTTP client library and can be plugged into the Faraday
# middleware stack to provide additional functionality.
#
# @example Using middleware in Faraday client
#   Faraday.new do |conn|
#     conn.use Fbe::Middleware::Formatter
#     conn.adapter Faraday.default_adapter
#   end
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
module Fbe::Middleware
end
