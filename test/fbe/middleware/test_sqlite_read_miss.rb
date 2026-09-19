# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require 'loog'
require 'tmpdir'
require_relative '../../../lib/fbe/middleware/sqlite_store'
require_relative '../../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class SqliteReadMissTest < Fbe::Test
  def test_runs_no_update_when_the_key_is_absent
    Dir.mktmpdir do |dir|
      store = Fbe::Middleware::SqliteStore.new(File.join(dir, 'c.db'), '0.0.1', loog: Loog::NULL)
      store.write(
        'one',
        [[JSON.dump({ 'method' => 'get', 'url' => 'https://api.github.com/x' }), JSON.dump({ 'status' => 200 })]]
      )
      seen = []
      spy =
        Module.new do
          define_method(:execute) do |sql, *args|
            seen << sql
            super(sql, *args)
          end
        end
      store.instance_variable_get(:@db).singleton_class.prepend(spy)
      assert_nil(store.read('absent-key'))
      assert_empty(seen.grep(/UPDATE/), 'a read that found nothing still updated the row')
      store.close
    end
  end
end
