# FactBase Extended (FBE)

[![DevOps By Rultor.com](https://www.rultor.com/b/zerocracy/fbe)](https://www.rultor.com/p/zerocracy/fbe)

[![rake](https://github.com/zerocracy/fbe/actions/workflows/rake.yml/badge.svg)](https://github.com/zerocracy/fbe/actions/workflows/rake.yml)
[![PDD status](https://www.0pdd.com/svg?name=zerocracy/fbe)](https://www.0pdd.com/p?name=zerocracy/fbe)
[![Gem Version](https://badge.fury.io/rb/fbe.svg)](https://badge.fury.io/rb/fbe)
[![Test Coverage](https://img.shields.io/codecov/c/github/zerocracy/fbe.svg)](https://codecov.io/github/zerocracy/fbe?branch=master)
[![Yard Docs](https://img.shields.io/badge/yard-docs-blue.svg)](https://rubydoc.info/github/zerocracy/fbe/master/frames)
[![Hits-of-Code](https://hitsofcode.com/github/zerocracy/fbe)](https://hitsofcode.com/view/github/zerocracy/fbe)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/zerocracy/fbe/blob/master/LICENSE.txt)

It's a collection of tools for
[zerocracy/judges-action](https://github.com/zerocracy/judges-action).
You are not supposed to use it directly, but only in a combination
with other tools of Zerocracy.

The following tools run a block:

* `Fbe.regularly` runs a block of code every X days.
* `Fbe.conclude` runs a block on every fact from a query.
* `Fbe.consider` runs a block on every fact from a query, letting it
change the fact.
* `Fbe.iterate` runs a block on each repository, until it's time to stop.
* `Fbe.unmask_repos` runs a block on each repository matching the masks,
or returns their list.
* `Fbe.repeatedly` runs a block of code every X hours, leaving
a fact-marker in the factbase.
* `Fbe.enter` runs a block inside a valve of Zerocracy.
* `Fbe.over?` tells whether the quota, the lifetime, or the timeout is over.

These tools help manage facts:

* `Fbe.fb` makes an entry point to the factbase.
* `Fbe.if_absent` creates a fact, unless a similar one already exists.
* `Fbe.just_one` finds a fact with the given properties, or creates it.
* `Fbe.overwrite` sets a property of a fact to another value, in place when
the property is absent, otherwise by deleting the fact and creating a new
similar one with all previous properties but this one.
* `Fbe.delete` removes properties from a fact.
* `Fbe.delete_one` removes one value of a property from a fact.
* `Fbe.copy` copies all properties of one fact to another.
* `Fbe.kill_if` deletes the given facts by their IDs.
* `Fbe::Tombstone` buries issue numbers of a repository and tells
whether one is buried.

They help with formatting:

* `Fbe.who` formats user name.
* `Fbe.issue` formats issue number.
* `Fbe::Award` calculates award by the bylaw.
* `Fbe.sec` formats seconds.

They help with external connections:

* `Fbe.octo` connects to GitHub API.
* `Fbe.github_graph` connects to GitHub GraphQL API.

They help with management:

* `Fbe.pmp` takes a PMP-related property by the area.
* `Fbe.bylaws` builds a hash with bylaws.

These are the helpers the tools above rely on:

* `Fbe.same?` tells whether a fact carries exactly the given times.
* `Fbe.mask_to_regex` turns a repository mask into a regular expression.
* `Fbe.testing?` tells whether the `testing` option is on.

## How to contribute

Read
[these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure your build is green before you contribute
your pull request. You will need to have
[Ruby](https://www.ruby-lang.org/en/) 3.3+ and
[Bundler](https://bundler.io/) installed. Then:

```bash
bundle update
bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.
