# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require 'tmpdir'
require_relative '../../lib/fbe/if_absent'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024-2026 Zerocracy
# License:: MIT
class TestIfAbsent < Fbe::Test
  def test_ignores
    fb = Factbase.new
    fb.insert.foo = 'hello dude'
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = 'hello dude'
      end
    assert_nil(n)
  end

  def test_raises_on_empty_value
    assert_raises(StandardError) do
      Fbe.if_absent(fb: Factbase.new) do |f|
        f.foo = ''
      end
    end
  end

  def test_raises_on_nil
    fb = Factbase.new
    fb.insert.foo = 42
    assert_raises(StandardError) do
      Fbe.if_absent(fb: Factbase.new) do |f|
        f.foo = nil
      end
    end
  end

  def test_ignores_with_time
    fb = Factbase.new
    t = Time.now
    fb.insert.foo = t
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = t
      end
    assert_nil(n)
  end

  def test_injects
    fb = Factbase.new
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = 42
      end
    assert_equal(42, n.foo)
  end

  def test_injects_and_reads
    Fbe.if_absent(fb: Factbase.new) do |f|
      f.foo = 42
      assert_equal(42, f.foo)
    end
  end

  def test_complex_ignores
    fb = Factbase.new
    f1 = fb.insert
    f1.foo = 'hello, "dude"!'
    f1.abc = 42
    t = Time.now
    f1.z = t
    f1.bar = 3.14
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = 'hello, "dude"!'
        f.abc = 42
        f.z = t
        f.bar = 3.14
      end
    assert_nil(n)
  end

  def test_complex_injects
    fb = Factbase.new
    f1 = fb.insert
    f1.foo = 'hello, dude!'
    f1.abc = 42
    t = Time.now
    f1.z = t
    f1.bar = 3.14
    n =
      Fbe.if_absent(fb:) do |f|
        f.foo = "hello, \\\"dude\\\" \\' \\' ( \n\n ) (!   '"
        f.abc = 42
        f.z = t + 1
        f.bar = 3.15
      end
    refute_nil(n)
  end
end
