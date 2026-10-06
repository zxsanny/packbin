#!/usr/bin/env bash
# Prints the exact version of tool $1 from tool-pins.txt. Exit 1 when the file has no single
# name==digits.dots line for it, so a missing or malformed pin never falls back to "latest".
set -euo pipefail
pins="$(dirname "${BASH_SOURCE[0]}")/tool-pins.txt"
tool="${1:?tool name}"
if ! awk -F'==' -v tool="$tool" '
  $1 == tool && $2 ~ /^[0-9]+(\.[0-9]+)*$/ { n++; v = $2 }
  END { if (n != 1) exit 1; print v }
' "$pins"; then
  echo "tool-pin: no single exact pin for '$tool' in $pins" >&2
  exit 1
fi
