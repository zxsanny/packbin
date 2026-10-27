#!/usr/bin/env bash
# Loop 75 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop75/smoke75.sh
# Needs Docker, python3 3.10+ first on PATH (or python/.venv), node 22 and npm; about 8 minutes on a quiet host
# (check `uptime` first). Step 11 of the loop (scripts/loop-tests.sh --all) is the total run; this script
# re-checks what the loop delivered: frame mode in C++, Go, Python and TypeScript.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
base=0fa21ce
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke75-failed-logs"
fails=0
trap 'if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke75: logs kept in $keep"; fi; rm -rf "$work"' EXIT
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2${4:+ [$4]}"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
code=0
dirty="$(git status --porcelain -- . ':(exclude)_docs')"
[ -z "$dirty" ] || code=1
step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"

# 2. TypeScript: the frame and crypto rows, the D1 names, the strict check.
code=0
(cd typescript && limit 900 npm test > "$work/ts.log" 2>&1 < /dev/null) || code=1
(cd typescript && limit 300 node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts > "$work/tsc.log" 2>&1 < /dev/null) || code=1
step 2 "TypeScript suite and strict tsc (frame 157 rows, crypto 27 rows, D1 names)" "$code" "$(grep -E '^# (pass|fail)' "$work/ts.log" | tr '\n' ' ')"

# 3. Python: the frame and crypto rows, the D1 names.
code=0
py=python/.venv/bin/python
[ -x "$py" ] || py=python3
(cd python && limit 900 "../$py" -m pytest tests -v --tb=short > "$work/py.log" 2>&1 < /dev/null) || (cd python && limit 900 "$py" -m pytest tests -v --tb=short > "$work/py.log" 2>&1 < /dev/null) || code=1
step 3 "Python suite (frame 157 rows, crypto 27 rows, D1 names)" "$code" "$(grep -o -E '[0-9]+ passed' "$work/py.log" | tail -n 1)"

# 4. Go: gofmt, vet and the race tests (frame 157 rows, crypto 27 rows, D1 names) in the golang image.
code=0
limit 1500 docker run --rm -v "$PWD":/src -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /src/go golang:1.27 \
  sh -c 'test -z "$(gofmt -l .)" && go vet ./... && go test -race -count=1 ./...' > "$work/go.log" 2>&1 < /dev/null || code=1
step 4 "Go gofmt, vet and race tests" "$code" "$(grep -E '^(ok|FAIL|--- FAIL)' "$work/go.log" | head -n 3 | tr '\n' ' ')"

# 5. C++: host suite on the Mac (frame 157 rows, crypto 27 rows, tag compare, D1 names), after a clean of the shared build.
code=0
make -C cpp clean > "$work/cppc.log" 2>&1 < /dev/null
limit 900 make -C cpp test > "$work/cpp.log" 2>&1 < /dev/null || code=1
make -C cpp clean >> "$work/cppc.log" 2>&1 < /dev/null
grep -q 'frame vectors: 157 of 157 rows pass' "$work/cpp.log" || code=1
grep -q 'crypto vectors: 27 of 27 rows pass' "$work/cpp.log" || code=1
step 5 "C++ host suite: 157 of 157 frame rows, 27 of 27 crypto rows" "$code" "$(grep -E 'frame vectors|all tests passed' "$work/cpp.log" | tr '\n' ' ')"

# 6. C++ embedded arm and AVR: the frame image pins and the older pins did not move.
code=0
limit 1500 docker compose -f docker-compose.test.yml run --rm cpp-embedded > "$work/arm.log" 2>&1 < /dev/null || code=1
for pat in 'm33f frame image flash=8416 budget=65536 pin=8416' 'm33f frame stack raw=976 meter overhead=64 net=912 budget=8192 pin=912'; do
  grep -q "$pat" "$work/arm.log" || { echo "missing: $pat"; code=1; }
done
step 6 "C++ arm and AVR rows pass; frame image 8,416 B flash / 912 B stack as pinned" "$code" "$(grep -E 'frame image|frame stack|targets failed' "$work/arm.log" | head -n 3 | tr '\n' ' ')"

# 7. The README frame examples of all eight packages equal their tests; the TypeScript declarations carry no Symbol.dispose.
code=0
bash scripts/frame/readme-examples.sh > "$work/readme.log" 2>&1 < /dev/null || code=1
[ "$(grep -c '^PASS' "$work/readme.log")" -eq 8 ] || code=1
(cd typescript && limit 300 node_modules/.bin/tsc -p tsconfig.build.json --outDir "$work/dts" > "$work/dts.log" 2>&1 < /dev/null) || code=1
! grep -rq 'dispose' "$work/dts" --include='*.d.ts' || code=1
step 7 "8 README frame examples equal their tests; no Symbol.dispose in the TypeScript declarations" "$code" "$(grep -c '^PASS' "$work/readme.log") README PASS"

# 8. Wire bytes and normative text unchanged since the loop 74 close: fixtures equal, contract Frame mode and MAC-only sections equal.
code=0
git diff --quiet "$base" HEAD -- fixtures/frame/vectors.txt fixtures/crypto/vectors.txt fixtures/ecc fixtures/golden.hex || code=1
bash fixtures/frame/check-vectors.test.sh > "$work/fxv.log" 2>&1 < /dev/null || code=1
contract=_docs/02_document/contracts/library/pack-session.md
[ "$(git show "$base:$contract" | sed -n '/^## Frame mode/,/^## Worked examples/p' | shasum -a 256)" = "$(sed -n '/^## Frame mode/,/^## Worked examples/p' "$contract" | shasum -a 256)" ] || code=1
step 8 "frame, crypto, ECC and golden fixtures and the contract's normative sections unchanged since $base" "$code"

# 9. Docs: no package is described as lacking frame mode; the consumer list names all eight.
code=0
live="$(git grep -n -i -E 'no session until|until its frame-mode port|frame mode comes to C\+\+|gains in a later release' -- README.md _docs/02_document ':(exclude)_docs/02_document/adr' | head -n 3)"
[ -z "$live" ] || code=1
grep -q 'AZ-3292' "$contract" && grep -q 'AZ-3295' "$contract" || code=1
step 9 "live docs and README describe frame mode in all eight packages" "$code" "$(printf '%s' "$live" | head -c 200)"

# 10. No touched source or test file grew past 500 lines (a new file over 500 lines counts).
code=0
long=""
for f in $(git diff --name-only --diff-filter=AM "$base" HEAD -- csharp java swift rust cpp go python typescript .github scripts fixtures | grep -E '\.(rs|cs|java|swift|cpp|hpp|go|py|ts|sh)$'); do
  [ -f "$f" ] || continue
  n="$(wc -l < "$f")"
  [ "$n" -gt 500 ] || continue
  old="$(git show "$base:$f" 2>/dev/null | wc -l)"
  [ "$n" -le "$old" ] || long="$long $f:$old->$n"
done
[ -z "$long" ] || code=1
step 10 "no touched source file grew past 500 lines" "$code" "$long"

echo "smoke75: $fails failed"
[ "$fails" -eq 0 ]
