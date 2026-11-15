# Contributing to CLDocs

CLDocs grows through pull requests. Everything you can add is a plain text file,
checked automatically and reviewed by a maintainer before it appears on the site.

By contributing you dedicate your work to the public domain under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Read the
[terms](#terms) below.

## Add an example (the common case)

1. Open the page of a symbol on the site and press **Add an example**. GitHub opens
   a new-file form already named and pre-filled. Or create the file yourself.
2. The file lives at `community/examples/<package>/<symbol>.txt`, with the package and
   symbol lowercased and unusual characters written as `_<hex>_` (the site does the
   encoding for you; `*print-base*` becomes `_2a_print-base_2a_`).
3. Write the file. `community/TEMPLATE.txt` shows everything:

   ```
   ;;; author: your-github-login
   ;;; license: CC0-1.0
   == MAPCAR
   (mapcar (lambda (x) (* x x)) '(1 2 3))
   -- silent
   (defun double (n)
     (* 2 n))
   (mapcar #'double '(1 2 3))
   ```

   - `== NAME` starts an example. For libraries write `== PACKAGE:NAME @ system`.
   - Every top-level form is a step; its printed value is recorded automatically.
   - `-- silent` before a form runs it without showing a result (use it for `defun`).
   - One file holds up to four examples and 8000 characters.
4. Open the pull request. A check runs your examples and tells you what is wrong.

### Rules the check enforces

- `;;; author:` with your GitHub login and `;;; license: CC0-1.0` (the CC0 dedication).
- The symbol must be documented on the site and the file must sit in the matching path.
- No `run-program`, sockets, `sb-posix`, `exit`, environment access or foreign calls.
- Files may only be touched under `/tmp/cldocs-`.
- Every step must run without an error and finish in 10 seconds.
- Results must not depend on the machine: no `random`, current time, addresses or
  environment-specific values; show a check such as `(integerp (random 10))` instead.

Good examples are small, show one idea, and mix styles: `#'builtin`, `(lambda ...)` and a
named function defined with `defun`.

## Other contributions

| What | Where |
|---|---|
| A translation of the interface | `data/i18n/messages.sexp` |
| A Portuguese summary of a symbol | `data/i18n/pt-br/<package>.sexp` |
| A new trail or changes to one | `data/trails/<slug>.sexp` |
| Related symbols ("see also") | `data/see-also/<package>.sexp` |
| A new library | add it to `data/systems.sexp`, then see below |

### Adding a library

1. Add `(:system "name" :packages ("PACKAGE"))` to `data/systems.sexp`; the library must
   declare a license in its `.asd`.
2. Run `sbcl --non-interactive --load scripts/ingest.lisp` to ingest it.
3. Write `data/examples-src/<package>.txt`, one to four examples per exported symbol, then
   `sbcl --non-interactive --load scripts/record-examples.lisp`.
4. Run the full check below.

## Checking your work locally

```bash
sbcl --non-interactive --load scripts/check-community.lisp   # only community files
sbcl --non-interactive --load scripts/check.lisp             # everything, a few minutes
sbcl --non-interactive --load scripts/build-site.lisp        # site into build/site/
```

You need SBCL (the project pins 2.6.9, see `scripts/ci-setup.sh`) and Quicklisp.

## Terms

- Everything you contribute is dedicated to the public domain under CC0 1.0. You must be
  the author or have the right to do so.
- Do not copy text or code from the Common Lisp HyperSpec, from books, or from projects
  whose license forbids it.
- Spam, advertising, abusive, misleading, unsafe or off-topic contributions are declined.
- Your GitHub login is public in the file and the repository history.

Be kind in reviews. Questions are welcome in issues.
