#!/bin/sh
# Install the pinned SBCL and Quicklisp dist used to record the checked-in data.
# Used by the GitHub Actions workflows; safe to run locally on x86-64 Linux.
set -eu
SBCL_VERSION="${SBCL_VERSION:-2.6.9}"
QUICKLISP_DIST="${QUICKLISP_DIST:-2026-01-01}"
PREFIX="$HOME/.local/sbcl"

if [ ! -x "$PREFIX/bin/sbcl" ]; then
  workdir="$(mktemp -d)"
  cd "$workdir"
  curl -fsSL -o sbcl.tar.bz2 \
    "https://downloads.sourceforge.net/project/sbcl/sbcl/$SBCL_VERSION/sbcl-$SBCL_VERSION-x86-64-linux-binary.tar.bz2"
  tar xjf sbcl.tar.bz2
  cd "sbcl-$SBCL_VERSION-x86-64-linux"
  INSTALL_ROOT="$PREFIX" sh install.sh
fi
export PATH="$PREFIX/bin:$PATH"
[ -z "${GITHUB_PATH:-}" ] || echo "$PREFIX/bin" >> "$GITHUB_PATH"

if [ ! -f "$HOME/quicklisp/setup.lisp" ]; then
  curl -fsSL -o /tmp/quicklisp.lisp https://beta.quicklisp.org/quicklisp.lisp
  sbcl --noinform --non-interactive \
    --load /tmp/quicklisp.lisp \
    --eval '(quicklisp-quickstart:install)' \
    --eval "(ql-dist:install-dist \"http://beta.quicklisp.org/dist/quicklisp/$QUICKLISP_DIST/distinfo.txt\" :prompt nil :replace t)"
fi
sbcl --version
