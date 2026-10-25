#!/usr/bin/env bash
# Proves the frame vectors check is not vacuous: the committed file passes, the generator is deterministic and
# reproduces the committed file, and a copy with one byte changed in a body, a tag, a result and a results list fails.
set -uo pipefail
cd "$(dirname "$0")/../.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

if bash fixtures/frame/check-vectors.sh >"$tmp/out" 2>&1; then pass committed; else fail "committed: $(cat "$tmp/out")"; fi

python3 -I scripts/frame/gen_vectors.py "$tmp/a.txt" >/dev/null && python3 -I scripts/frame/gen_vectors.py "$tmp/b.txt" >/dev/null
if cmp -s "$tmp/a.txt" "$tmp/b.txt"; then pass "deterministic: two runs identical"; else fail "deterministic: two runs differ"; fi
if cmp -s "$tmp/a.txt" fixtures/frame/vectors.txt; then pass "generator reproduces the committed file"; else fail "generator output differs from fixtures/frame/vectors.txt"; fi

# corrupt <name> <case> <field>: flips the last hex digit of the field (or a result word) on that row
corrupt() {
    local name="$1" case="$2" field="$3" copy="$tmp/$1.txt"
    python3 - "$case" "$field" "$copy" <<'PY'
import sys
case, field, out = sys.argv[1:4]
lines = open("fixtures/frame/vectors.txt").read().split("\n")
for i, line in enumerate(lines):
    if line.startswith("op=") and (" case=%s " % case) in line + " ":
        tokens = line.split(" ")
        for j, token in enumerate(tokens):
            if token.startswith(field + "="):
                value = token[len(field) + 1:]
                if field == "result":
                    value = "Duplicate" if value != "Duplicate" else "TooOld"
                elif field == "results":
                    value = "Duplicate" + value[len(value.split(",")[0]):]
                else:
                    value = value[:-1] + ("0" if value[-1] != "0" else "1")
                tokens[j] = field + "=" + value
        lines[i] = " ".join(tokens)
open(out, "w").write("\n".join(lines))
PY
    if bash fixtures/frame/check-vectors.sh "$copy" >"$tmp/out" 2>&1; then
        fail "$name: the corrupted copy passed"
    elif grep -q "$case" "$tmp/out"; then
        pass "$name: failed naming $case"
    else
        fail "$name: failed without naming $case: $(head -3 "$tmp/out")"
    fi
}
corrupt body-corrupt E1.seal body
corrupt tag-corrupt E4.mac tag
corrupt result-corrupt refuse.seal.dir4 result
corrupt results-corrupt replay.seq17 results

[ "$fails" -eq 0 ] && echo "frame vectors tests passed" || { echo "$fails failed"; exit 1; }
