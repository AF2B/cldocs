# CLDocs

Community reference for Common Lisp: one page per symbol with signature,
documentation, executable examples, "see also" links and guided trails, in English
and Brazilian Portuguese. Inspired by ClojureDocs, styled with the Borba Design System.

It is a **static site** built from versioned data and published on GitHub Pages.
Anyone extends it with a pull request; nothing needs a server, a database or HTTPS.

References: CLHS, CLtL2, the SBCL manual (`sb-introspect`, `sb-cltl2`), the ASDF manual
and Quicklisp.

## Contribute

Press **Add an example** on any symbol page, or read [CONTRIBUTING.md](CONTRIBUTING.md).
An example is one small text file; a check runs it and a maintainer reviews it.

## Quick start

```bash
sbcl --non-interactive --load scripts/check.lisp            # load without warnings + all tests
sbcl --non-interactive --load scripts/check-community.lisp  # only the contributed examples
sbcl --non-interactive --load scripts/build-site.lisp       # site into build/site/
sbcl --non-interactive --load scripts/ingest.lisp           # regenerate data/ from SBCL and libraries
sbcl --non-interactive --load scripts/record-examples.lisp  # re-run seeded examples and store results
```

`check.lisp` fails on any `WARNING` or `STYLE-WARNING` from project code and on any failing
test (Lisp suite plus Node tests for the browser scripts). The data was recorded with SBCL
2.6.9 and Quicklisp dist 2026-01-01; `scripts/ci-setup.sh` installs exactly those.

Local preview: `cd build/site && python3 -m http.server 8765`, then open
`http://localhost:8765/` (English) or `/pt-br/` (Português).

## What is in the box

| Part | Where | Notes |
|---|---|---|
| Ingestion | `src/introspect.lisp`, `src/ingest.lisp` | Kinds, lambda lists and docstrings from the live SBCL image; each library in its own child image with a time limit; systems without a license are refused |
| Versioned data | `data/packages/*.sexp`, `data/MANIFEST.sexp` | Human readable and diff friendly, with SBCL and Quicklisp versions and SHA-256 digests |
| HyperSpec links | `data/clhs-map.sexp` | Only symbol-name to page-name facts; HyperSpec text and images are never copied |
| Seeded examples | `data/examples-src/*.txt`, `data/examples/*.sexp` | CC0; every example runs in SBCL and its recorded results are re-checked by the tests |
| Community examples | `community/examples/` | Validated, executed with a timeout and credited to their author |
| Trails | `data/trails/*.sexp` | 15 reading paths by theme |
| Translations | `data/i18n/` | Interface strings and Portuguese summaries, as plain data |
| Static site | `src/site.lisp`, `src/render.lisp`, `assets/` | Pages in both languages, client-side search (`/` focuses it) |
| Live server (optional, experimental) | `src/server/` | GitHub sign-in, SQLite and a moderation queue; not used by the Pages deployment |

Documented packages: `COMMON-LISP`, `ALEXANDRIA`, `ANAPHORA`, `BABEL`, `BORDEAUX-THREADS`,
`CL-PPCRE`, `ITERATE`, `SPLIT-SEQUENCE`, `STR` (add systems in `data/systems.sexp`).

## Deploying to GitHub Pages

1. Push the repository to GitHub and enable **Settings → Pages → Source: GitHub Actions**.
2. The `Pages` workflow builds and publishes on every push to `main`.
3. For a custom domain or a user site (`<user>.github.io`) set `CLDOCS_BASE_PATH` to `/` in
   `.github/workflows/pages.yml`.

The `CI` workflow runs the full check on pull requests. Both workflows install the pinned
SBCL from `scripts/ci-setup.sh`; verify that download URL on the first run.

## Security model

- Contributions are reviewed by a maintainer and executed only on ephemeral CI runners
  without secrets. The Pages build job has read-only permissions.
- The static rules in `src/community.lisp` (author and CC0 line, known symbol, forbidden
  constructs, file access under `/tmp/cldocs-`, 10 second step timeout) are defence in
  depth, not a sandbox; read every file before merging. See `SECURITY.md`.
- User text is escaped by Spinneret; the optional live server adds a strict CSP, hashed
  sessions and CSRF tokens (see `src/server/`).

## Legal

The Common Lisp HyperSpec is copyright LispWorks Ltd. CLDocs links to it and never copies
its text or images. Code is MIT (`LICENSE`); examples and translations are CC0; docstrings
keep the license of the system that provides them. Details in `NOTICE.md`.
