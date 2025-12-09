# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'delegate'
require 'nokogiri'
require 'others'
require_relative '../fbe'
require_relative 'fb'

# Takes configuration parameter from the "PMP" fact.
#
# The factbase may have a few facts with the +what+ set to +pmp+ (stands for the
# "project management plan"). These facts contain information that configures
# the project. It is expected that every fact with the +what+ set to +pmp+ also
# contains the +area+ property, which is set to one of nine values: +scope+,
# +time+, +cost+, etc. (the nine process areas in the PMBOK).
#
# If a proper pmp fact is not found or the property is absent in the fact,
# this method throws an exception. The factbase must contain PMP-related facts.
# Most probably, a special judge must fill it up with such a fact.
#
# The method uses a double nested `others` block to create a chainable interface
# that allows accessing configuration like:
#
#   Fbe.pmp.hr.reward_points
#   Fbe.pmp.cost.hourly_rate
#   Fbe.pmp.time.deadline
#
# @param [Factbase] fb The factbase
# @param [Hash] global The hash for global caching
# @param [Judges::Options] options The options coming from the +judges+ tool
# @param [Loog] loog The logging facility
# @return [Object] A proxy object that allows method chaining to access PMP properties
# @example
#   # Get HR reward points from PMP configuration
#   points = Fbe.pmp.hr.reward_points
#
#   # Get hourly rate from cost area
#   rate = Fbe.pmp.cost.hourly_rate
#
#   # Get deadline from time area
#   deadline = Fbe.pmp.time.deadline
def Fbe.pmp(fb: Fbe.fb, global: $global, options: $options, loog: $loog)
  xml = Nokogiri::XML(File.read(File.join(__dir__, '../../assets/pmp.xml')))
  pmpv =
    Class.new(SimpleDelegator) do
      def initialize(value, dv)
        super(value)
        @dv = dv
      end

      def default
        @dv
      end
    end
  Class.new do
    define_method(:areas) do
      xml.xpath('/pmp/area/@name').map(&:value)
    end
    others do |*args1|
      area = args1.first.to_s
      node = xml.at_xpath("/pmp/area[@name='#{area}']")
      raise "Unknown area #{area.inspect}" if node.nil?
      Class.new do
        define_method(:properties) do
          node.xpath('p/name').map(&:text)
        end
        others do |*args2|
          param = args2.first.to_s
          f = Fbe.fb(global:, fb:, options:, loog:).query("(and (eq what 'pmp') (eq area '#{area}'))").each.first
          r = f&.[](param)&.first
          prop = node.at_xpath("p[name='#{param}']")
          dv = nil
          if prop
            d = prop.at_xpath('default').text
            t = prop.at_xpath('type').text
            dv =
              case t
              when 'int' then d.to_i
              when 'float' then d.to_f
              else d
              end
          end
          pmpv.new(r || dv, dv)
        end
      end.new
    end
  end.new
end
