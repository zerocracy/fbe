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

require_relative '../fbe'
require_relative 'unmask_repos'
require_relative 'octo'
require_relative 'fb'

# Create a conclude code block.
def Fbe.iterate(fb: Fbe.fb, loog: $loog, options: $options, global: $global, &)
  c = Fbe::Iterate.new(fb:, loog:, options:, global:)
  c.instance_eval(&)
end

# Iterate.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Zerocracy
# License:: MIT
class Fbe::Iterate
  def initialize(fb:, loog:, options:, global:)
    @fb = fb
    @loog = loog
    @options = options
    @global = global
    @label = nil
    @since = 0
    @query = nil
    @repeats = 1
    @quota_aware = false
  end

  def quota_aware
    @quota_aware = true
  end

  def repeats(repeats)
    raise 'Cannot set "repeats" to nil' if repeats.nil?
    raise 'The "repeats" must be a positive integer' unless repeats.positive?
    @repeats = repeats
  end

  def by(query)
    raise 'Query is already set' unless @query.nil?
    raise 'Cannot set query to nil' if query.nil?
    @query = query
  end

  def as(label)
    raise 'Label is already set' unless @label.nil?
    raise 'Cannot set "label" to nil' if label.nil?
    @label = label
  end

  # It makes a number of repeats of going through all repositories
  # provided by the "repositories" configuration option. In each "repeat"
  # it yields the repository ID and a number that is retrieved by the
  # "query". The query is supplied with two parameter:
  # "$before" (the value from the previous repeat and "$rid" (the repo ID).
  def over(&)
    raise 'Use "as" first' if @label.nil?
    raise 'Use "by" first' if @query.nil?
    seen = {}
    oct = Fbe.octo(loog: @loog, options: @options, global: @global)
    repos = Fbe.unmask_repos(loog: @loog, options: @options, global: @global)
    restarted = []
    loop do
      repos.each do |repo|
        next if restarted.include?(repo)
        seen[repo] = 0 if seen[repo].nil?
        if seen[repo] >= @repeats
          @loog.debug("We've seen too many (#{seen[repo]}) in #{repo}, let's see next one")
          next
        end
        rid = oct.repo_id_by_name(repo)
        before = @fb.query(
          "(agg (and (eq what '#{@label}') (eq where 'github') (eq repository #{rid})) (first latest))"
        ).one
        @fb.query("(and (eq what '#{@label}') (eq where 'github') (eq repository #{rid}))").delete!
        before = before.nil? ? @since : before.first
        nxt = @fb.query(@query).one(before:, repository: rid)
        after =
          if nxt.nil?
            @loog.debug("Next element after ##{before} not suggested, re-starting from ##{@since}: #{@query}")
            restarted << repo
            @since
          else
            @loog.debug("Next is ##{nxt}, starting from it...")
            yield(rid, nxt)
          end
        raise "Iterator must return an Integer, while #{after.class} returned" unless after.is_a?(Integer)
        f = @fb.insert
        f.where = 'github'
        f.repository = rid
        f.latest =
          if after.nil?
            @loog.debug("After is nil at #{repo}, setting the 'latest' to ##{nxt}")
            nxt
          else
            @loog.debug("After is ##{after} at #{repo}, setting the 'latest' to it")
            after
          end
        f.what = @label
        seen[repo] += 1
        if oct.off_quota
          @loog.debug('We are off GitHub quota, time to stop')
          break
        end
      end
      if oct.off_quota
        @loog.debug('We are off GitHub quota, time to stop')
        break
      end
      unless seen.any? { |r, v| v < @repeats && !restarted.include?(r) }
        @loog.debug("No more repos to scan (out of #{repos.size}), quitting")
        break
      end
      if restarted.size == repos.size
        @loog.debug("All #{repos.size} repos restarted, quitting")
        break
      end
    end
    @loog.debug("Finished scanning #{repos.size} repos: #{seen.map { |k, v| "#{k}:#{v}" }.join(', ')}")
  end
end
