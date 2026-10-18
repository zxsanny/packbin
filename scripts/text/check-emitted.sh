#!/usr/bin/env bash
# Every package keeps the constants of fixtures/text/tables.json in one emitted file; this proves each is exactly
# what scripts/text/emit_tables.py writes today. Usage: check-emitted.sh [repository root]
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$(cd "$here/../.." && pwd)}"
failures=0

for lang in python typescript csharp java rust go swift cpp; do
  rel="$(python3 "$here/emit_tables.py" "$lang" --path < /dev/null)"
  if [ ! -f "$root/$rel" ]; then
    echo "check-emitted: $lang: $rel is missing" >&2
    failures=$((failures + 1))
  elif python3 "$here/emit_tables.py" "$lang" --check "$root/$rel" < /dev/null; then
    echo "check-emitted: $lang ok ($rel)"
  else
    echo "check-emitted: $lang: $rel differs from the emitter output" >&2
    failures=$((failures + 1))
  fi
done
[ "$failures" -eq 0 ]
