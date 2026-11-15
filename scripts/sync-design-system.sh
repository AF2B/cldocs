#!/bin/sh
# Refresh vendor/borba-design-system/ from the source of truth.
set -eu
SOURCE="${CLDOCS_DESIGN_SYSTEM_SOURCE:-$HOME/Documents/borba-design-system}"
TARGET="$(dirname "$0")/../vendor/borba-design-system"
for file in tipografia.md tokens.css fonts/Inter.ttf fonts/JetBrainsMono.ttf; do
  [ -f "$SOURCE/$file" ] || { echo "missing $SOURCE/$file" >&2; exit 1; }
  mkdir -p "$TARGET/$(dirname "$file")"
  cp "$SOURCE/$file" "$TARGET/$file"
done
echo "Synced from $SOURCE"
