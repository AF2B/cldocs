# Licenses of what CLDocs contains

CLDocs mixes several kinds of material. Each keeps its own license.

| Material | Where | License |
|---|---|---|
| CLDocs source code | `src/`, `scripts/`, `tests/`, `assets/` | MIT, see `LICENSE` |
| Examples, trails, translations, see-also groups | `data/examples-src/`, `data/examples/`, `data/trails/`, `data/i18n/`, `data/see-also/`, `community/` | CC0 1.0 (public domain dedication) |
| Symbol names, kinds, lambda lists | `data/packages/` | Facts extracted by introspection |
| Docstrings from SBCL | `data/packages/common-lisp.sexp` | SBCL is public domain, apart from some files under BSD-style licenses |
| Docstrings from libraries | `data/packages/<library>.sexp` | The license of each library, recorded in the file and shown on its pages: alexandria (Public Domain / 0-clause MIT), anaphora (Public Domain), babel (MIT), bordeaux-threads (MIT), cl-ppcre (BSD), iterate (MIT), split-sequence (MIT), str (MIT) |
| Common Lisp HyperSpec | linked only | Copyright LispWorks Ltd. Never copied; `data/clhs-map.sexp` holds only symbol-name to page-name facts |
| Inter, JetBrains Mono fonts | `vendor/borba-design-system/fonts/` | SIL Open Font License 1.1 (from Google Fonts) |
| Borba Design System tokens | `vendor/borba-design-system/` | André Borba; a snapshot, see its README |

Contributions to `community/` are accepted under CC0 1.0, see `CONTRIBUTING.md`.
