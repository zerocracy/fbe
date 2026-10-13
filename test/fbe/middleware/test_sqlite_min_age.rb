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
class SqliteMinAgeTest < Fbe::Test
  def test_raises_the_age_of_every_variant
    Dir.mktmpdir do |dir|
      store = Fbe::Middleware::SqliteStore.new(File.join(dir, 'c.db'), '0.0.1', loog: Loog::NULL, cache_min_age: 300)
      value =
        (1..2).map do |i|
          [
            JSON.dump({ 'method' => 'get', 'url' => "https://api.github.com/x/#{i}" }),
            JSON.dump({ 'response_headers' => { 'cache-control' => 'public, max-age=60' } })
          ]
        end
      store.write('one', value)
      back = store.read('one')
      back.each_with_index do |pair, i|
        assert_equal('public, max-age=300', JSON.parse(pair[1])['response_headers']['cache-control'], "variant #{i}")
      end
      store.close
    end
  end
end
