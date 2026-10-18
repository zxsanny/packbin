#!/usr/bin/env bash
# Proves check-emitted.sh passes on emitted files and fails on a changed byte and on a missing file.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

for lang in python typescript csharp java rust go swift cpp; do
  rel="$(python3 "$here/emit_tables.py" "$lang" --path < /dev/null)"
  mkdir -p "$work/ok/$(dirname "$rel")"
  python3 "$here/emit_tables.py" "$lang" < /dev/null > "$work/ok/$rel"
done
bash "$here/check-emitted.sh" "$work/ok" > /dev/null || { echo "FAIL: emitted files do not pass" >&2; exit 1; }
echo "ok: emitted files pass"

cp -R "$work/ok" "$work/changed"
rel="$(python3 "$here/emit_tables.py" go --path < /dev/null)"
sed -e 's/1072/1073/' "$work/ok/$rel" > "$work/changed/$rel"
if bash "$here/check-emitted.sh" "$work/changed" > /dev/null 2>&1; then echo "FAIL: a changed constant was accepted" >&2; failures=$((failures + 1)); else echo "ok: a changed constant is refused"; fi

cp -R "$work/ok" "$work/missing"
rm "$work/missing/$(python3 "$here/emit_tables.py" swift --path < /dev/null)"
if bash "$here/check-emitted.sh" "$work/missing" > /dev/null 2>&1; then echo "FAIL: a missing file was accepted" >&2; failures=$((failures + 1)); else echo "ok: a missing file is refused"; fi

[ "$failures" -eq 0 ]
