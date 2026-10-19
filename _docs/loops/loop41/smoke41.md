# Loop 41 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. F52: a Rust handler above 32 parity bytes is refused before any byte is read (plain and session)
- [x] 4. F53: a C# session without parity packs and reads a 300-byte message
- [x] 5. F54: Python refuses a raw text for its length before the copy and the decode
- [x] 6. AC-1 and AC-2: the security report has the loop 41 addendum with F51 to F60 and no open High or Critical
- [x] 7. The audit probes of all eight packages are in `fixtures/hostile/fuzz/`, none over 500 lines, and the Python edge probe passes
- [x] 8. The next loop's spec AZ-2713 is in `todo/` and unclaimed
- [x] 9. No source file this loop touched is over 500 lines
- [x] 10. Nothing is released: no tag holds HEAD

## Result

Agent run 2026-10-19 at `b5d2ad8` (owner rule 2026-10-12 in `deployment_procedures.md`): **10/10 steps passed**. Step 11 ran at `a9f4540`: 12 passed, 1 skipped as unchanged (cpp-embedded-arm), 0 failed, 975 s, no serial retries (typescript 11 s, csharp 59, rust 75, java 37, python 171, go 183, cpp 70, scaffold 296, swift 368, ring 59, ac10 5, publish gate 361). After the F54 test move the smoke re-ran the python stage (124 s, pass).

## For the operator

- The first `v*` tag, F44 and the `go/v*` tag are yours.
- AZ-2713 (strictly ascending dict keys, F51 and F56) is the next loop; the Lows F57 to F60 and the F19 instances are listed as candidates for it.

## Script (`bash smoke41.sh`)

```bash
#!/usr/bin/env bash
# Loop 41 smoke (security audit of the text and ECC decoders, AZ-2666): smoke41.sh. One line per step: [n/N] title,
# then PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/pybin" && ln -s /opt/homebrew/bin/python3.14 "$work/pybin/python3"
N=10 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="$work/pybin:/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "F52: a Rust handler above 32 parity bytes is refused before any byte is read"
if (cd rust && cargo test --test ecc_session_dispatch_tests above_32 < /dev/null > "$work/out.log" 2>&1) && grep -q 'test result: ok. 2 passed' "$work/out.log"; then ok "2 tests (plain and session)"; else ko "the Rust BadParity tests failed"; fi

step "F53: a C# session without parity takes a 300-byte message"
if env MSBUILDDISABLENODEREUSE=1 dotnet test csharp/tests --nologo --filter "FullyQualifiedName~SessionPack_WithoutParity_TakesAClearMessageAbove254Bytes" < /dev/null > "$work/out.log" 2>&1 && grep -q 'Passed!' "$work/out.log"; then ok "$(grep 'Passed!' "$work/out.log" | sed 's/ - .*//')"; else ko "the C# test failed"; fi

step "F54: Python refuses a raw text for its length before the copy and the decode"
if python/.venv/bin/python -m pytest python/tests/test_text_raw_limit.py -v --tb=short -p no:cacheprovider < /dev/null > "$work/out.log" 2>&1; then ok "$(tail -1 "$work/out.log")"; else ko "the Python tests failed"; fi

step "AC-1 and AC-2: the loop 41 addendum with F51 to F60 and no open High or Critical"
report=_docs/05_security/security_report.md
rows="$(awk '/^## Loop 41 addendum/,0' "$report" | grep -cE '^\| (5[1-9]|60) \|')"
open_high="$(awk '/^## Loop 41 addendum/,0' "$report" | grep -E '^\| (5[1-9]|60) \| (High|Critical) \|' | grep -c 'open')"
if [ "$rows" -eq 10 ] && [ "$open_high" -eq 0 ] && grep -q 'Critical 0, High 0' "$report"; then ok "10 finding rows, 0 open High or Critical"; else ko "rows=$rows open_high=$open_high"; fi

step "The audit probes of all eight packages are kept, none over 500 lines, the Python edge probe passes"
missing="" long=""
for d in python typescript rust go csharp java swift cpp; do [ -n "$(find "fixtures/hostile/fuzz/$d" -type f 2>/dev/null)" ] || missing="$missing $d"; done
long="$(find fixtures/hostile/fuzz -type f | while read -r f; do [ "$(wc -l < "$f")" -gt 500 ] && echo "$f"; done)"
if [ -z "$missing" ] && [ -z "$long" ] && /opt/homebrew/bin/python3.14 -I -B fixtures/hostile/fuzz/python/edges.py "$repo" < /dev/null > "$work/out.log" 2>&1 && grep -q '^0 FAIL' "$work/out.log"; then ok "8 directories; edges.py 0 FAIL"; else ko "missing:${missing:- none} long:${long:- none}"; fi

step "The next loop's spec AZ-2713 is in todo/ and unclaimed"
spec=_docs/02_tasks/todo/AZ-2713_dict_keys_ascending.md
if [ -f "$spec" ] && ! head -3 "$spec" | grep -q '^loop:'; then ok "AZ-2713 unclaimed"; else ko "spec missing or claimed"; fi

step "No source file this loop touched is over 500 lines"
long="$(git diff --name-only 915a908 HEAD | grep -vE '^_docs/|\.md$' | while read -r f; do [ -f "$f" ] && wc -l < "$f" | awk -v f="$f" '$1 > 500 {print $1, f}'; done)"
if [ -z "$long" ]; then ok "none over 500 lines"; else ko "$long"; fi

step "Nothing is released: no tag holds HEAD"
if [ -z "$(git tag --contains HEAD)" ]; then ok "no tag"; else ko "a tag holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
