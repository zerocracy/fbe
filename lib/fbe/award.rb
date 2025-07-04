# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase/syntax'
require 'joined'
require_relative 'fb'

# A generator of awards.
#
# First, you should create a bylaw, using the same Lisp-ish syntax as
# we use in queries to a Factbase, for example:
#
#  require 'fbe/award'
#  a = Fbe::Award.new('(award (in loc "lines") (give (times loc 5) "for LoC"))')
#
# Then, you can either get a bill from it:
#
#  b = a.bill(loc: 345)
#  puts b.points  # how many points to reward, a number
#  puts b.greeting  # how to explain the reward, a text
#
# Or else, you can get a bylaw text:
#
#  p = a.bylaw
#  puts p.markdown  # Markdown of the bylaw
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class Fbe::Award
  # Ctor.
  # @param [String, nil] query The query with the bylaw
  # @param [String] judge The name of the judge
  # @param [Hash] global The hash for global caching
  # @param [Judges::Options] options The options coming from the +judges+ tool
  # @param [Loog] loog The logging facility
  def initialize(query = nil, judge: $judge, global: $global, options: $options, loog: $loog)
    query = Fbe.pmp(fb: Fbe.fb, global:, options:, loog:).hr.send(judge.tr('-', '_')) if query.nil?
    @query = query
  end

  # Build a bill object from this award query.
  # @param [Hash] vars Hash of variables
  # @return [Fbe::Award::Bill] The bill
  def bill(vars = {})
    term = Factbase::Syntax.new(@query).to_term
    term.redress!(Fbe::Award::BTerm)
    bill = Bill.new
    vars.each { |k, v| bill.set(k, v) }
    term.bill_to(bill)
    bill
  end

  # Build a bylaw object from this award query.
  # @return [Fbe::Award::Bylaw] The bylaw
  def bylaw
    term = Factbase::Syntax.new(@query).to_term
    term.redress!(Fbe::Award::PTerm)
    bylaw = Bylaw.new
    term.publish_to(bylaw)
    bylaw
  end

  # A term module for processing award billing logic.
  #
  # This module is used to extend Factbase terms to handle award calculations
  # and billing operations. It provides methods to calculate point values and
  # evaluate complex award expressions.
  module BTerm
    # Returns a string representation of the term.
    #
    # @return [String] The term as a string in S-expression format
    # @example
    #   term.to_s #=> "(give (times loc 5) 'for LoC')"
    def to_s
      "(#{@op} #{@operands.join(' ')})"
    end

    # Indicates whether the term is static.
    #
    # @return [Boolean] Always returns true for BTerm
    def static?
      true
    end

    # Indicates whether the term is abstract.
    #
    # @return [Boolean] Always returns false for BTerm
    def abstract?
      false
    end

    # Processes this term and applies its operations to a bill.
    #
    # @param [Fbe::Award::Bill] bill The bill to update
    # @return [nil]
    # @raise [RuntimeError] If there's a failure processing any term
    # @example
    #   term = Factbase::Syntax.new('(award (give 100 "for effort"))').to_term
    #   term.redress!(Fbe::Award::BTerm)
    #   bill = Fbe::Award::Bill.new
    #   term.bill_to(bill)
    #   bill.points #=> 100
    def bill_to(bill)
      case @op
      when :award
        @operands.each do |o|
          o.bill_to(bill)
        rescue StandardError => e
          raise "Failure in #{o}: #{e.message}"
        end
      when :aka
        @operands[0..-2].each do |o|
          o.bill_to(bill)
        rescue StandardError => e
          raise "Failure in #{o}: #{e.message}"
        end
      when :let, :set
        v = to_val(@operands[1], bill)
        raise "Can't #{@op.inspect} #{@operands[0].inspect} to nil" if v.nil?
        bill.set(@operands[0], v)
      when :give
        text = @operands[1]
        text = '' if text.nil?
        bill.line(to_val(@operands[0], bill), text)
      when :explain, :in
        # nothing, just ignore
      else
        raise "Unknown term '#{@op}'"
      end
    end

    # Evaluates a value in the context of a bill.
    #
    # @param [Object] any The value to evaluate (symbol, term, or literal)
    # @param [Fbe::Award::Bill] bill The bill providing context for evaluation
    # @return [Object] The evaluated value
    # @raise [RuntimeError] If a symbol isn't found in the bill
    # @example
    #   bill = Fbe::Award::Bill.new
    #   bill.set(:loc, 100)
    #   term.to_val(:loc, bill) #=> 100
    def to_val(any, bill)
      if any.is_a?(BTerm)
        any.calc(bill)
      elsif any.is_a?(Symbol)
        v = bill.vars[any]
        raise "Unknown name #{any.inspect} among: #{bill.vars.keys.map(&:inspect).joined}" if v.nil?
        v
      else
        any
      end
    end

    # Calculates the value of this term in the context of a bill.
    #
    # This method evaluates terms like arithmetic operations, logical
    # operations, and other expressions based on the operator type.
    #
    # @param [Fbe::Award::Bill] bill The bill providing context for calculation
    # @return [Object] The calculated value (number, boolean, etc.)
    # @raise [RuntimeError] If the term operation is unknown
    # @example
    #   bill = Fbe::Award::Bill.new
    #   bill.set(:x, 10)
    #   bill.set(:y, 5)
    #   term = Factbase::Syntax.new('(times x y)').to_term
    #   term.redress!(Fbe::Award::BTerm)
    #   term.calc(bill) #=> 50
    def calc(bill)
      case @op
      when :total
        bill.points
      when :if
        to_val(@operands[0], bill) ? to_val(@operands[1], bill) : to_val(@operands[2], bill)
      when :and
        @operands.all? { |o| to_val(o, bill) }
      when :or
        @operands.any? { |o| to_val(o, bill) }
      when :not
        !to_val(@operands[0], bill)
      when :eq
        to_val(@operands[0], bill) == to_val(@operands[1], bill)
      when :lt
        to_val(@operands[0], bill) < to_val(@operands[1], bill)
      when :lte
        to_val(@operands[0], bill) <= to_val(@operands[1], bill)
      when :gt
        to_val(@operands[0], bill) > to_val(@operands[1], bill)
      when :gte
        to_val(@operands[0], bill) >= to_val(@operands[1], bill)
      when :div
        to_val(@operands[0], bill) / to_val(@operands[1], bill)
      when :times
        to_val(@operands[0], bill) * to_val(@operands[1], bill)
      when :plus
        to_val(@operands[0], bill) + to_val(@operands[1], bill)
      when :minus
        to_val(@operands[0], bill) - to_val(@operands[1], bill)
      when :max
        [to_val(@operands[0], bill), to_val(@operands[1], bill)].max
      when :min
        [to_val(@operands[0], bill), to_val(@operands[1], bill)].min
      when :between
        v = to_val(@operands[0], bill)
        a = to_val(@operands[1], bill)
        b = to_val(@operands[2], bill)
        min, max = [a, b].minmax
        return 0 if (!v.negative? && v < min) || (!v.positive? && v > max)
        v.clamp(min, max)
      else
        raise "Unknown term '#{@op}'"
      end
    end
  end

  # A term for bylaw.
  module PTerm
    def to_s
      case @op
      when :total
        'total'
      when :if
        "if #{to_p(@operands[0])} then #{to_p(@operands[1])} else #{to_p(@operands[2])}"
      when :and
        @operands.map(&:to_s).join(' and ')
      when :or
        @operands.map(&:to_s).join(' or ')
      when :not
        "not #{@operands[0]}"
      when :eq
        "#{to_p(@operands[0])} = #{to_p(@operands[1])}"
      when :lt
        "#{to_p(@operands[0])} < #{to_p(@operands[1])}"
      when :lte
        "#{to_p(@operands[0])} ≤ #{to_p(@operands[1])}"
      when :gt
        "#{to_p(@operands[0])} > #{to_p(@operands[1])}"
      when :gte
        "#{to_p(@operands[0])} ≥ #{to_p(@operands[1])}"
      when :div
        "#{to_p(@operands[0])} ÷ #{to_p(@operands[1])}"
      when :times
        "#{to_p(@operands[0])} × #{to_p(@operands[1])}"
      when :plus
        "#{to_p(@operands[0])} + #{to_p(@operands[1])}"
      when :minus
        "#{to_p(@operands[0])} - #{to_p(@operands[1])}"
      when :max
        "maximum of #{to_p(@operands[0])} and #{to_p(@operands[1])}"
      when :min
        "minimum of #{to_p(@operands[0])} and #{to_p(@operands[1])}"
      when :between
        "at least #{to_p(@operands[0])} and at most #{to_p(@operands[1])}"
      else
        raise "Unknown term '#{@op}'"
      end
    end

    def static?
      true
    end

    def abstract?
      false
    end

    def publish_to(bylaw)
      case @op
      when :award
        @operands.each do |o|
          o.publish_to(bylaw)
        rescue StandardError => e
          raise "Failure in #{o}: #{e.message}"
        end
      when :aka
        @operands[0..-2].each do |o|
          o.publish_to(bylaw)
        rescue StandardError => e
          raise "Failure in #{o}: #{e.message}"
        end
        bylaw.revert(@operands.size - 1)
        bylaw.line(to_p(@operands[@operands.size - 1]))
      when :explain
        bylaw.intro(to_p(@operands[0]))
      when :in
        bylaw.line("assume that #{to_p(@operands[0])} is #{to_p(@operands[1])}")
      when :let
        bylaw.line("let #{to_p(@operands[0])} be equal to #{to_p(@operands[1])}")
        bylaw.let(@operands[0], @operands[1])
      when :set
        bylaw.line("set #{to_p(@operands[0])} to #{to_p(@operands[1])}")
      when :give
        bylaw.line("award #{to_p(@operands[0])}")
      else
        raise "Unknown term '#{@op}'"
      end
    end

    def to_p(any)
      case any
      when PTerm
        any.to_s
      when Symbol
        s = any.to_s
        subs = {
          0 => '₀',
          1 => '₁',
          2 => '₂',
          3 => '₃',
          4 => '₄',
          5 => '₅',
          6 => '₆',
          7 => '₇',
          8 => '₈',
          9 => '₉'
        }
        s.gsub!(/([a-z]+)([0-9])/) { |_| "#{Regexp.last_match[1]}#{subs[Regexp.last_match[2].to_i]}" }
        "_#{s.tr('_', '-')}_"
      when Integer, Float
        "**#{any}**"
      else
        any
      end
    end
  end

  # A bill class that accumulates points and explanations for rewards.
  #
  # This class tracks variables, point values, and explanatory text
  # for each award component. It provides methods to calculate total points
  # and generate a human-readable summary of the rewards.
  class Bill
    # @return [Hash] Variables set in this bill
    attr_reader :vars

    # Creates a new empty bill.
    #
    # @example
    #   bill = Fbe::Award::Bill.new
    def initialize
      @lines = []
      @vars = {}
    end

    # Sets a variable in the bill's context.
    #
    # @param [Symbol] var The variable name
    # @param [Object] value The value to assign
    # @return [Object] The assigned value
    # @example
    #   bill = Fbe::Award::Bill.new
    #   bill.set(:lines_of_code, 500)
    def set(var, value)
      @vars[var] = value
    end

    # Adds a point value with explanatory text to the bill.
    #
    # @param [Integer, Float] value The point value to add
    # @param [String] text The explanation for these points
    # @return [nil]
    # @note Zero-valued points are ignored
    # @example
    #   bill = Fbe::Award::Bill.new
    #   bill.line(50, "for code review")
    def line(value, text)
      return if value.zero?
      text = text.gsub(/\$\{([a-z_0-9]+)\}/) { |_x| @vars[Regexp.last_match[1].to_sym] }
      @lines << { v: value, t: text }
    end

    # Calculates the total points in this bill.
    #
    # @return [Integer] The sum of all point values, rounded to an integer
    # @example
    #   bill = Fbe::Award::Bill.new
    #   bill.line(42.5, "for answer")
    #   bill.points #=> 43
    def points
      @lines.sum { |l| l[:v] }.to_f.round.to_i
    end

    # Generates a human-readable summary of the bill.
    #
    # @return [String] A description of the points earned
    # @example
    #   bill = Fbe::Award::Bill.new
    #   bill.line(50, "for code review")
    #   bill.line(25, "for documentation")
    #   bill.greeting #=> "You've earned +75 points for this: +50 for code review; +25 for documentation. "
    def greeting
      items = @lines.map { |l| "#{format('%+d', l[:v])} #{l[:t]}" }
      case items.size
      when 0
        "You've earned nothing. "
      when 1
        "You've earned #{format('%+d', points)} points. "
      else
        "You've earned #{format('%+d', points)} points for this: #{items.join('; ')}. "
      end
    end
  end

  # A class for generating human-readable bylaws.
  #
  # This class builds textual descriptions of award bylaws including
  # introductions, calculation steps, and variable substitutions.
  # It produces Markdown-formatted output describing how awards are calculated.
  class Bylaw
    # @return [Hash] Variables defined in this bylaw
    attr_reader :vars

    # Creates a new empty bylaw.
    #
    # @example
    #   bylaw = Fbe::Award::Bylaw.new
    def initialize
      @lines = []
      @intro = ''
      @lets = {}
    end

    # Removes the specified number of most recently added lines.
    #
    # @param [Integer] num The number of lines to remove from the end
    # @return [Array] The removed lines
    # @example
    #   bylaw = Fbe::Award::Bylaw.new
    #   bylaw.line("award 50 points")
    #   bylaw.line("award 30 points")
    #   bylaw.revert(1) # Removes "award 30 points"
    def revert(num)
      @lines.slice!(-num, num)
    end

    # Sets the introductory text for the bylaw.
    #
    # @param [String] text The introductory text to set
    # @return [String] The introductory text
    # @example
    #   bylaw = Fbe::Award::Bylaw.new
    #   bylaw.intro("This bylaw determines rewards for code contributions")
    def intro(text)
      @intro = text
    end

    # Adds a line of text to the bylaw, replacing variable references.
    #
    # @param [String] line The line of text to add
    # @return [nil]
    # @example
    #   bylaw = Fbe::Award::Bylaw.new
    #   bylaw.let(:points, 50)
    #   bylaw.line("award ${points} points")
    def line(line)
      line = line.gsub(/\$\{([a-z_0-9]+)\}/) { |_x| "**#{@lets[Regexp.last_match[1].to_sym]}**" }
      @lines << line
    end

    # Registers a variable with its value for substitution in lines.
    #
    # @param [Symbol] key The variable name
    # @param [Object] value The value to associate with the variable
    # @return [Object] The assigned value
    # @example
    #   bylaw = Fbe::Award::Bylaw.new
    #   bylaw.let(:points, 50)
    def let(key, value)
      @lets[key] = value
    end

    # Generates a Markdown-formatted representation of the bylaw.
    #
    # @return [String] The bylaw formatted as Markdown text
    # @example
    #   bylaw = Fbe::Award::Bylaw.new
    #   bylaw.intro("This bylaw determines rewards for code contributions")
    #   bylaw.line("award **50** points")
    #   bylaw.markdown
    #   #=> "This bylaw determines rewards for code contributions. Just award **50** points."
    def markdown
      pars = []
      pars << "#{@intro}." unless @intro.empty?
      pars << 'Here is how it\'s calculated:'
      if @lines.size == 1
        pars << "Just #{@lines.first}."
      else
        pars += @lines.each_with_index.map { |t, i| "#{i.zero? ? 'First' : 'Then'}, #{t}." }
      end
      pars.join(' ').gsub('. Then, award ', ', and award ').gsub(/\s{2,}/, ' ')
    end
  end
end
