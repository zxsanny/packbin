#!/usr/bin/env bash
# Usage: expect-fail.sh "<compile command>" <source> "<text the error must contain>"
set -u
cmd="$1"
src="$2"
want="$3"
out="build/$(basename "$src").out"
if $cmd "$src" >"$out" 2>&1; then
  echo "compile-fail: $src compiled, expected an error containing: $want"
  exit 1
fi
if ! grep -q -- "$want" "$out"; then
  echo "compile-fail: $src failed without the expected text: $want"
  cat "$out"
  exit 1
fi
echo "compile-fail: $src rejected ($want)"
