# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'factbase/syntax'

# A generator of awards.
#
# First, you should create a policy, using the same Lisp-ish syntax as
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
# Or else, you can get a policy text:
#
#  p = a.policy
#  puts p.markdown  # Markdown of the policy
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class Fbe::Award
  def initialize(query = J.pmp.hr.send($judge.gsub('-', '_')))
    @query = query
  end

  def bill(vars = {})
    term = Factbase::Syntax.new(@query, term: Fbe::Award::BTerm).to_term
    bill = Bill.new
    vars.each { |k, v| bill.set(k, v) }
    term.bill_to(bill)
    bill
  end

  def policy
    term = Factbase::Syntax.new(@query, term: Fbe::Award::PTerm).to_term
    policy = Policy.new
    term.publish_to(policy)
    policy
  end

  # A term for bill.
  class BTerm
    def initialize(operator, operands)
      @op = operator
      @operands = operands
    end

    def to_s
      "(#{@op} #{@operands.join(' ')})"
    end

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
        bill.set(@operands[0], to_val(@operands[1], bill))
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

    def to_val(any, bill)
      if any.is_a?(BTerm)
        any.calc(bill)
      elsif any.is_a?(Symbol)
        v = bill.vars[any]
        raise "Unknown name '#{any}' among [#{bill.vars.keys.join(', ')}]" if v.nil?
        v
      else
        any
      end
    end

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

  # A term for policy.
  class PTerm
    def initialize(operator, operands)
      @op = operator
      @operands = operands
    end

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

    def publish_to(policy)
      case @op
      when :award
        @operands.each do |o|
          o.publish_to(policy)
        rescue StandardError => e
          raise "Failure in #{o}: #{e.message}"
        end
      when :aka
        @operands[0..-2].each do |o|
          o.publish_to(policy)
        rescue StandardError => e
          raise "Failure in #{o}: #{e.message}"
        end
        policy.revert(@operands.size - 1)
        policy.line(to_p(@operands[@operands.size - 1]))
      when :explain
        policy.intro(to_p(@operands[0]))
      when :in
        policy.line("assume that #{to_p(@operands[0])} is #{to_p(@operands[1])}")
      when :let
        policy.line("let #{to_p(@operands[0])} be equal to #{to_p(@operands[1])}")
        policy.let(@operands[0], @operands[1])
      when :set
        policy.line("set #{to_p(@operands[0])} to #{to_p(@operands[1])}")
      when :give
        policy.line("award #{to_p(@operands[0])}")
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
        "_#{s.gsub('_', '-')}_"
      when Integer, Float
        "**#{any}**"
      else
        any
      end
    end
  end

  # A bill.
  class Bill
    attr_reader :vars

    def initialize
      @lines = []
      @vars = {}
    end

    def set(var, value)
      @vars[var] = value
    end

    def line(value, text)
      return if value.zero?
      text = text.gsub(/\$\{([a-z_0-9]+)\}/) { |_x| @vars[Regexp.last_match[1].to_sym] }
      @lines << { v: value, t: text }
    end

    def points
      @lines.map { |l| l[:v] }.inject(&:+).to_i
    end

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

  # A policy.
  class Policy
    attr_reader :vars

    def initialize
      @lines = []
      @intro = ''
      @lets = {}
    end

    def revert(num)
      @lines.slice!(-num, num)
    end

    def intro(text)
      @intro = text
    end

    def line(line)
      line = line.gsub(/\$\{([a-z_0-9]+)\}/) { |_x| "**#{@lets[Regexp.last_match[1].to_sym]}**" }
      @lines << line
    end

    def let(key, value)
      @lets[key] = value
    end

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
