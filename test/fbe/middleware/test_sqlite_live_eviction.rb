# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'securerandom'
require 'tmpdir'
require_relative '../../../lib/fbe/middleware'
require_relative '../../../lib/fbe/middleware/sqlite_store'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class SqliteLiveEvictionTest < Fbe::Test
  def test_keeps_the_file_within_the_limit_while_writing
    Dir.mktmpdir do |dir|
      f = File.expand_path('e.db', dir)
      store = Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog, maxsize: '64Kb', maxvsize: '1Mb')
      500.times { |i| store.write("k#{i}", SecureRandom.alphanumeric(2_048)) }
      assert_operator(File.size(f), :<=, 128 * 1024)
    end
  end

  def test_does_not_serve_an_expired_entry
    Dir.mktmpdir do |dir|
      f = File.expand_path('t.db', dir)
      now = Time.now
      store = Fbe::Middleware::SqliteStore.new(f, '0.0.1', loog: fake_loog, ttl: 24)
      Time.stub(:now, now - (7 * 24 * 60 * 60)) do
        store.write('k1', 'value1')
      end
      assert_nil(store.read('k1'))
    end
  end
end
