# Changelog

All notable changes are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-15

First complete release: a static, community-extensible reference for Common Lisp.

### Added
- Ingestion of `COMMON-LISP` from the live SBCL image into versioned, diff-friendly data
  with a manifest of SBCL and Quicklisp versions and file digests.
- Library ingestion, one child SBCL per system with a time limit, refusing systems
  without a license: alexandria, anaphora, babel, bordeaux-threads, cl-ppcre, iterate,
  split-sequence and str (1486 documented symbols in total).
- Static site with one page per symbol, package pages, HyperSpec links (facts only),
  "see also" links and client-side search with keyboard navigation.
- 2800+ examples, one to four per symbol, each executed in SBCL and re-checked by the
  tests; they mix lambdas, built-in functions and user-defined named functions.
- 15 thematic trails (lists, sequences, strings, numbers, control flow, functions,
  hash tables, conditions, CLOS, macros, packages, streams, types, libraries).
- Brazilian Portuguese edition under `/pt-br/`: interface, trails, terms and summaries
  of the core symbols, with a language switch on every page.
- Community contributions by pull request: files in `community/examples/` are validated
  (author, CC0 license, known symbol, safety rules), executed with a timeout and credited
  to their author on the page. "Add an example" button pre-fills the GitHub new-file form.
- GitHub Actions: full check on pull requests, deploy to GitHub Pages on merge.
- Vendored Borba Design System snapshot so the site builds anywhere.
- Optional live server (experimental): GitHub sign-in, SQLite, moderation queue. It is
  not needed for the Pages deployment.

### Notes
- The Pages workflow pins SBCL 2.6.9 and Quicklisp dist 2026-01-01, the toolchain the
  checked-in data was recorded with.
