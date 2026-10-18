#!/usr/bin/env bash
# Usage: frame-check.sh "<compile command ending in -c -o <object>>"
# The warning needs code generation, so this is not a -fsyntax-only case.
set -euo pipefail
cmd="$1"
out="build/frame-check.out"
if $cmd tests/compile-fail/scratch_local_large.cpp >"$out" 2>&1; then
  echo "frame-check: a local Scratch<65535> compiled; -Wframe-larger-than is not in force"
  exit 1
fi
if ! grep -E -q -- "frame size|stack frame|larger than" "$out"; then
  echo "frame-check: the local Scratch<65535> failed without a frame-size message"
  cat "$out"
  exit 1
fi
if ! $cmd tests/compile-fail/scratch_static_large.cpp >"$out" 2>&1; then
  echo "frame-check: a static Scratch<65535> was rejected"
  cat "$out"
  exit 1
fi
echo "frame-check: local Scratch<65535> rejected, static accepted"
