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

The following tools runs a block:

* `Fbe.regularly` runs a block of code every X days.
* `Fbe.conclude` runs a block on every fact from a query.
* `Fbe.iterate` runs a block on each repository, until it's time to stop.
* `Fbe.repeatedly` runs a block of code every X hours, leaving
a fact-marker in the factbase.

These tools help manage facts:

* `Fbe.fb` makes an entry point to the factbase.
* `Fbe.overwrite` changes a property in a fact to another value by deleting
the fact first, and then creating a new similar fact with all previous
properties but one changed.

They help with formatting:

* `Fbe.who` formats user name.
* `Fbe.issue` formats issue number.
* `Fbe.award` calculates award by the bylaw.
* `Fbe.sec` formats seconds.

They help with external connections:

* `Fbe.octo` connects to GitHub API.

They help with management:

* `Fbe.pmp` takes a PMP-related property by the area.
* `Fbe.bylaws` builds a hash with bylaws.

## How to contribute

Read
[these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure your build is green before you contribute
your pull request. You will need to have
[Ruby](https://www.ruby-lang.org/en/) 3.2+ and
[Bundler](https://bundler.io/) installed. Then:

```bash
bundle update
bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.
