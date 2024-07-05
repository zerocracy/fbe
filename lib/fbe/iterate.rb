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
def Fbe.iterate(fbx = Fbe.fb, loog = $loog, &)
  c = Fbe::Iterate.new(fbx, loog)
  c.instance_eval(&)
end

# Iterate.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Zerocracy
# License:: MIT
class Fbe::Iterate
  def initialize(fb, loog)
    @fb = fb
    @loog = loog
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
    raise 'Cannot set "repeats" to larger than 8' if repeats > 8
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

  def over(&)
    raise 'Use "as" first' if @label.nil?
    raise 'Use "by" first' if @query.nil?
    seen = {}
    oct = Fbe.octo(loog: @loog)
    repos = Fbe.unmask_repos(loog: @loog)
    loop do
      repos.each do |repo|
        seen[repo] = 0 if seen[repo].nil?
        if seen[repo] > @repeats
          @loog.debug("We've seen too many in the #{repo} repo, time to move to the next one")
          next
        end
        rid = oct.repo_id_by_name(repo)
        before = Fbe.fb.query(
          "(agg (and (eq what '#{@label}') (eq where 'github') (eq repository #{rid})) (first latest))"
        ).one
        Fbe.fb.query("(and (eq what '#{@label}') (eq where 'github') (eq repository #{rid}))").delete!
        before = before.nil? ? @since : before[0]
        nxt = Fbe.fb.query(@query).one(before:, repository: rid)
        after =
          if nxt.nil?
            @loog.debug("Next is nil, starting from the beginning at #{@since}")
            @since
          else
            @loog.debug("Next is #{nxt}, starting from it...")
            yield(rid, nxt)
          end
        raise "Iterator must return an Integer, while #{after.class} returned" unless after.is_a?(Integer)
        f = Fbe.fb.insert
        f.where = 'github'
        f.repository = rid
        f.latest =
          if after.nil?
            @loog.debug("After is nil at #{repo}, setting the `latest` to nxt: #{nxt}")
            nxt
          else
            @loog.debug("After is #{after} at #{repo}, setting the `latest` to it")
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
      unless seen.values.any? { |v| v < @repeats }
        @loog.debug('No more repos to scan, quitting')
        break
      end
    end
    @loog.debug("Finished scanning #{repos.size} repos: #{seen.map { |k, v| "#{k}:#{v}" }.join(', ')}")
  end
end
