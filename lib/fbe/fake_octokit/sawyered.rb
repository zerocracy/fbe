# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'sawyer'
require_relative 'answer'

# Turns the answers of the fake into the kind of object a real client gives.
#
# A real client answers with a +Sawyer::Resource+, which reads as +r.name+,
# as +r[:name]+ and as +r['name']+. The fake used to answer with a plain
# +Hash+, which reads only as +r[:name]+, so a judge written as +json.name+
# raised only in tests, and one written as +json['name']+ read +nil+ only in
# tests, which is worse, because nothing fails and the fact quietly gets the
# wrong value.
#
# @note Every public method of {Fbe::FakeOctokit} goes through this
class Fbe::FakeOctokit::Sawyered < Module
  # Builds the module and puts a wrapper around each of the given methods.
  #
  # @param [Array<Symbol>] methods The methods to wrap
  def initialize(methods)
    super()
    wrap = method(:resource)
    methods.each do |m|
      define_method(m) do |*args, **kwargs, &block|
        wrap.call(super(*args, **kwargs, &block))
      end
    end
  end

  # Wraps one answer, and everything inside it.
  #
  # @param [Object] obj The answer of the fake
  # @return [Object] The same, as an answer if it was a hash
  def resource(obj)
    case obj
    when Hash
      Fbe::FakeOctokit::Answer.new(Sawyer::Agent.new('https://api.github.com'), obj)
    when Array
      obj.map { |o| resource(o) }
    else
      obj
    end
  end
end

Fbe::FakeOctokit.__send__(:prepend, Fbe::FakeOctokit::Sawyered.new(Fbe::FakeOctokit.instance_methods(false)))
