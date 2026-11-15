# CLDocs

Community reference for Common Lisp: one page per symbol with signature,
documentation string, executable examples, "see also" links and community
contributions. Inspired by ClojureDocs. Styled with the Borba Design System.

Built with SBCL, ASDF and Quicklisp. References: CLHS, CLtL2, the SBCL manual
(`sb-introspect`, `sb-cltl2`), the ASDF manual and Quicklisp.

## Quick start

```bash
sbcl --non-interactive --load scripts/check.lisp        # load without warnings + all tests
sbcl --non-interactive --load scripts/ingest.lisp       # regenerate data/ from SBCL and libraries
sbcl --non-interactive --load scripts/record-examples.lisp
sbcl --non-interactive --load scripts/build-site.lisp   # static site into build/site/
sbcl --non-interactive --load scripts/serve.lisp        # site + community API on :8080
```

`check.lisp` fails on any `WARNING` or `STYLE-WARNING` raised by project code
and on any failing test (Lisp suite, plus Node tests for the browser scripts).

## What is in the box

| Part | Where | Notes |
|---|---|---|
| Ingestion | `src/introspect.lisp`, `src/ingest.lisp` | Kinds, lambda lists and docstrings from the live SBCL image; libraries each in a child image with a time limit; systems without a license are refused |
| Versioned data | `data/packages/*.sexp`, `data/MANIFEST.sexp` | Human readable, diff friendly, with SBCL and Quicklisp versions and SHA-256 digests |
| HyperSpec links | `data/clhs-map.sexp` | Only the symbol-name to page-name facts; HyperSpec text and images are never copied |
| Examples | `data/examples-src/*.txt`, `data/examples/*.sexp` | CC0; every example is executed in SBCL and its recorded results are re-checked by the tests |
| See also | `data/see-also/`, `src/related.lisp` | Curated groups plus symbols sharing a HyperSpec page |
| Static site | `src/site.lisp`, `src/render.lisp`, `assets/` | One page per symbol, package pages, client-side search (`/` to focus) |
| Community API | `src/server/` | GitHub sign-in, SQLite, moderation queue, flags, rate limit |

Documented today: `COMMON-LISP`, `ALEXANDRIA`, `BORDEAUX-THREADS`, `CL-PPCRE`
(add systems in `data/systems.sexp`).

## Server configuration

Environment variables only; secrets never go in files.

| Variable | Meaning |
|---|---|
| `CLDOCS_BASE_URL` | Public address (default `http://localhost:8080`); `https://` turns on Secure cookies and HSTS |
| `CLDOCS_PORT`, `CLDOCS_DATABASE`, `CLDOCS_SITE_DIRECTORY` | Listen port, SQLite file, generated site (default `build/site/`) |
| `CLDOCS_GITHUB_CLIENT_ID`, `CLDOCS_GITHUB_CLIENT_SECRET` | GitHub OAuth app; callback is `<base>/oauth/callback`; no scopes are requested |
| `CLDOCS_MODERATORS` | Comma separated GitHub logins allowed to use `/admin` |
| `CLDOCS_DEV_LOGIN` | Enables `/dev-login?as=name`; refused unless the base URL is localhost |

## Security model

- Contributions are never executed and stay `pending` until a moderator approves them.
- Strict CSP (`default-src 'none'`, scripts and styles from `self` only), `nosniff`, `X-Frame-Options: DENY`.
- User text is escaped by Spinneret on the server and written with `textContent` in the browser.
- Sessions: random tokens, only their SHA-256 is stored; HttpOnly, SameSite=Lax cookies.
- State changes need a CSRF token bound to the session; OAuth uses a verified `state` cookie.
- Limits: 4000 characters, at most 2 links, 10 submissions per hour per user, 16 KB request bodies.
- Three distinct flags send a published item back to review. Authors can withdraw their own items.
- SQL always uses bound parameters.

## Legal

The Common Lisp HyperSpec is copyright LispWorks Ltd. CLDocs links to it and
never copies its text or images. Docstrings are shown under the license of the
system that provides them. Contribution terms: `/terms/` (version in
`cldocs/render:+terms-version+`).
