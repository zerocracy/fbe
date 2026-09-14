# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../../lib/fbe/issue'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestIssue < Fbe::Test
  def test_simple
    fb = Factbase.new
    f = fb.insert
    f.repository = 323
    f.issue = 333
    global = {}
    options = Judges::Options.new({ 'testing' => true })
    assert_equal('yegor256/test#333', Fbe.issue(f, global:, options:, loog: Loog::NULL))
  end

  def test_rejects_ambiguous_identifiers_before_lookup
    %i[repository issue].each do |prop|
      fact = Factbase.new.insert
      fact.repository = 323
      fact.issue = 333
      fact.public_send("#{prop}=", 444)
      Fbe.stub(:octo, ->(**) { flunk('Ambiguous identifiers must not request a GitHub client') }) do
        error =
          assert_raises(Fbe::Error) do
            Fbe.issue(fact, global: {}, options: Judges::Options.new({ 'testing' => true }), loog: Loog::NULL)
          end
        assert_includes(error.message, prop.to_s)
        assert_includes(error.message, 'exactly one')
      end
    end
  end
end
