#!/usr/bin/env bash
# Proves that check-vectors.sh fails on corrupted copies of the vectors file and of the tables, and passes on the real files.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
check="$here/check-vectors.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

expect_fail() {
  local name="$1" vectors="$2" tables="${3:-$here/tables.json}"
  if "$check" "$vectors" "$tables" > "$work/out.log" 2>&1; then
    echo "FAIL: $name was accepted" >&2
    failures=$((failures + 1))
  else
    echo "ok: $name is refused"
  fi
}

"$check" > "$work/real.log" 2>&1 || { cat "$work/real.log" >&2; echo "FAIL: the real files do not pass" >&2; exit 1; }
echo "ok: the real files pass"

v="$here/vectors.txt"
first_enc="$(grep -m1 '^enc ' "$v")"
mutated="${first_enc%?}0"
[ "$mutated" != "$first_enc" ] || mutated="${first_enc%?}1"
awk -v a="$first_enc" -v b="$mutated" '$0 == a { print b; next } { print }' "$v" > "$work/m1.txt"
expect_fail "a changed field byte" "$work/m1.txt"

awk '/^enc / { n++; if (n > 40) next } { print }' "$v" > "$work/m2.txt"
expect_fail "too few enc rows" "$work/m2.txt"

sed -e 's/^bad bad.mode_5 mode /bad bad.mode_5 mdoe /' "$v" > "$work/m3.txt"
expect_fail "a misspelled refusal kind" "$work/m3.txt"

{ cat "$v"; grep -m1 '^enc ' "$v"; } > "$work/m4.txt"
expect_fail "a duplicate id" "$work/m4.txt"

sed -e 's/^bad bad.varint_not_minimal varint /bad bad.varint_not_minimal short /' "$v" > "$work/m5.txt"
expect_fail "a wrong refusal kind" "$work/m5.txt"

grep -v '^flip ' "$v" > "$work/m6.txt"
expect_fail "no flip rows" "$work/m6.txt"

sed -e 's/^flip flip.hand.hello enc.hand.hello$/flip flip.hand.hello enc.hand.no_such_row/' "$v" > "$work/m7.txt"
expect_fail "a flip row naming a missing row" "$work/m7.txt"

grep -v '^ref ref.nested ' "$v" > "$work/m8.txt"
expect_fail "a missing ring packet" "$work/m8.txt"

sed -e 's/^alt alt.escape_for_letter \(.*\)$/enc alt.escape_for_letter \1/' "$v" > "$work/m9.txt"
expect_fail "an alt row written as enc" "$work/m9.txt"

python3 - "$here/tables.json" "$work/tables_bad.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf8"))
d["modes"]["ua"]["lengths"][0] += 1
json.dump(d, open(sys.argv[2], "w", encoding="utf8"), ensure_ascii=False)
PY
expect_fail "a table that is not a complete code" "$v" "$work/tables_bad.json"

if [ "$failures" -ne 0 ]; then
  echo "check-vectors.test.sh: $failures mutant(s) accepted" >&2
  exit 1
fi
echo "check-vectors.test.sh: every mutant is refused"
