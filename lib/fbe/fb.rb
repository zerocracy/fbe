# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'factbase/logged'
require 'factbase/pre'
require 'factbase/rules'
require 'factbase/cached/cached_factbase'
require 'factbase/indexed/indexed_factbase'
require 'factbase/sync/sync_factbase'
require 'judges'
require 'loog'
require_relative '../fbe'

# Returns an instance of +Factbase+ (cached).
#
# Instead of using +$fb+ directly, it is recommended to use this utility
# method. It will not only return the global factbase, but will also
# make sure it's properly decorated and cached.
#
# @param [Factbase] fb The global factbase provided by the +judges+ tool
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @return [Factbase] The global factbase
def Fbe.fb(fb: $fb, global: $global, options: $options, loog: $loog)
  global[:fb] ||=
    begin
      fbe = Factbase::Logged.new(fb, loog)
      rules = Dir.glob(File.join('rules', '*.fe')).map { |f| File.read(f) }
      fbe = Factbase::Rules.new(
        fbe,
        "(and \n#{rules.join("\n")}\n)",
        uid: '_id'
      )
      fbe =
        Factbase::Pre.new(fbe) do |f, fbt|
          max = fbt.query('(max _id)').one
          f._id = (max.nil? ? 0 : max) + 1
          f._time = Time.now
          f._version = "#{Factbase::VERSION}/#{Judges::VERSION}/#{options.action_version}"
          f._job = options.job_id unless options.job_id.nil?
        end
      Factbase::SyncFactbase.new(
        Factbase::IndexedFactbase.new(
          Factbase::CachedFactbase.new(
            fbe
          )
        )
      )
    end
end
