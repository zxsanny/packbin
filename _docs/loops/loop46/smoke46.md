# Loop 46 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. AZ-2735: a text concurrency test exists in C#, Java, Rust, Go and Swift
- [x] 4. AZ-2736: CS-5 and CS-10 say 3,000 and 30,000; Python, C# and Swift have the random and hostile tests; Go runs 30,000 payloads
- [x] 5. AZ-2737: repeated-text tests in Java, C#, Rust and C++ (3 s bound, registered in main.cpp); the Java cache and its alternating-text test
- [x] 6. AZ-2739: `session_ecc_hex`, 32 `session-ecc` pairs and the commands in the eight drivers
- [x] 7. AZ-2740 AC-1: the five test-spec cases hold compact hex
- [x] 8. AZ-2740 AC-2: the matrix is at most 500 lines and the side file holds the loop 45 rows
- [x] 9. AZ-2740 AC-3: a rerun of `size_report.py` gives the committed file except the date
- [x] 10. TW-10: nothing under `cpp/src`, `cpp/include` or `cpp/embedded` changed in this loop
- [x] 11. The loop 46 reports: the plan, the retro, the structure snapshot, 15 lessons
- [x] 12. Nothing is released: no tag holds HEAD

## Result

Agent run 2026-10-20 at `bfb9a76` (owner rule 2026-10-12 in `deployment_procedures.md`): **12/12 steps passed**. Step 2 re-ran every stage (12 passed, 1 skipped as unchanged, 1,063 s) and this time C++ passed in the pool; the first step 11 run passed 12 stages in 1,191 s with C++ on the serial retry (host load 45, 3.538 s against 3.331 s).

## For the operator

- The first `v*` tag, F44 and the `go/v*` tag are yours; CS-D5 waits for the 100 to 200 real messages.
- Jira: epic AZ-2645 stays open for AZ-2742 (C++ shortcut for the repeated text).
- Leftovers: the split of `language-pair.sh` (545 lines), the Swift concurrency test in the CI thread-sanitizer step, the vcpkg checks (NOT RUN on this Mac).

## Script (`bash smoke46.sh`)

```bash
#!/usr/bin/env bash
# Loop 46 smoke (text and ECC test waves; AZ-2735, AZ-2736, AZ-2737, AZ-2739, AZ-2740). One line per step: [n/N] title,
# then PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=12 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "No application source is dirty at the close"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" limit 3600 scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "AZ-2735: a text concurrency test exists in C#, Java, Rust, Go and Swift"
miss=""
for f in csharp/tests/CompactTextTests.Concurrency.cs java/src/test/java/packbin/TextConcurrencyTest.java rust/src/text_concurrency_tests.rs go/text_concurrency_test.go swift/Tests/PackbinTests/TextConcurrencyTests.swift; do [ -f "$f" ] || miss="$miss $f"; done
if [ -z "$miss" ] && grep -q 'mod text_concurrency_tests' rust/src/lib.rs && grep -q 'TextConcurrencyTest.run' java/src/test/java/packbin/PackbinTest.java; then ok "five test files, registered in Rust and Java"; else echo "missing:$miss" > "$work/out.log"; ko "concurrency tests missing or not registered"; fi

step "AZ-2736: CS-5/CS-10 numbers, the Python, C# and Swift tests, Go at 30,000"
a=_docs/02_task_plans/compact-strings/acceptance_criteria.md
if grep -q 'at least 3,000 random Unicode strings per package' "$a" && grep -q 'At least 30,000 hostile payloads per package' "$a" \
  && [ -f python/tests/test_compact_text_random.py ] && [ -f csharp/tests/CompactTextTests.Random.cs ] && [ -f csharp/tests/CompactTextTests.Hostile.cs ] \
  && [ -f swift/Tests/PackbinTests/TextRandomTests.swift ] && [ -f swift/Tests/PackbinTests/TextHostilePayloadTests.swift ] && grep -q 'for range 30000' go/text_positions_test.go; then ok "criteria 3,000 / 30,000; five new test files; Go 30,000"; else ko "criteria text, a new test file or the Go count is missing"; fi

step "AZ-2737: repeated-text tests in Java, C#, Rust, C++; the Java cache and its alternating-text test"
if [ -f java/src/test/java/packbin/TextRepeatSpeedTest.java ] && [ -f csharp/tests/CompactTextTests.Repeat.cs ] && [ -f rust/src/text_repeat_tests.rs ] && [ -f cpp/tests/core/text_repeat_host_tests.cpp ] \
  && grep -q 'run_core_text_repeat_host_tests' cpp/tests/core/main.cpp && grep -q 'load_factor::bound(3.0)' cpp/tests/core/text_repeat_host_tests.cpp \
  && grep -q 'lastField' java/src/main/java/packbin/ByteSink.java && grep -q 'differentTextsBetweenEqualOnesAreEachEncodedFromTheirOwnBytes' java/src/test/java/packbin/TextRepeatSpeedTest.java; then ok "four repeat tests, C++ registered with the 3 s bound, Java cache and test"; else ko "a repeat test, the C++ registration or the Java cache test is missing"; fi

step "AZ-2739: session_ecc_hex, 32 session-ecc pairs, the commands in the eight drivers"
pairs="$(grep -c '^handoff .* session-ecc "\$session_ecc_hex"' .github/workflows/language-pair.sh)"
drv="$(grep -rl 'pack-session-ecc' .github/workflows/drivers | wc -l | tr -d ' ')"
if grep -q '^session_ecc_hex="b55d0a29c56c203712b241232e2ce30c57"' .github/workflows/language-pair.sh && [ "$pairs" -eq 32 ] && [ "$drv" -ge 8 ]; then ok "hex pinned, $pairs pairs, $drv driver files"; else echo "pairs=$pairs drivers=$drv" > "$work/out.log"; ko "session-ecc wiring incomplete"; fi

step "AZ-2740 AC-1: the five test-spec cases hold compact hex"
b=_docs/02_document/tests/blackbox-tests-02-strings-lists-dicts.md
if ! grep -qE '07007a78|000000000000|020003006d6170' "$b" && grep -q '^\*\*Expected outcome\*\*: hex `01062bfcfee119b2' "$b" && grep -q 'hex `010000000000`' "$b" && grep -q '49 bytes' "$b"; then ok "no old-format hex; 79-byte user, 6-byte empty triple, 49-byte nested"; else ko "an old-format hex is left or a compact hex is missing"; fi

step "AZ-2740 AC-2: the matrix is at most 500 lines; the side file holds the loop 45 rows"
m=_docs/02_document/tests/traceability-matrix.md; s=_docs/02_document/tests/traceability-matrix-loops-35-46-text.md
lines="$(wc -l < "$m" | tr -d ' ')"
if [ "$lines" -le 500 ] && [ "$(grep -cE '^\| (CS|HD|RL)-[0-9]+ ' "$s")" -ge 29 ] && ! grep -qE '^\| (CS|HD|RL)-[0-9]+ ' "$m" && grep -q 'traceability-matrix-loops-35-46-text.md' "$m"; then ok "matrix $lines lines; side file holds the CS, HD, RL rows"; else ko "matrix $lines lines or the rows are not where they should be"; fi

step "AZ-2740 AC-3: a rerun of size_report.py gives the committed file except the date"
if /opt/homebrew/bin/python3.14 scripts/text/size_report.py fixtures/text/vectors.txt "$work/size.md" > /dev/null 2>&1 \
  && diff <(grep -v '^Written by' _docs/02_task_plans/compact-strings/size_report.md) <(grep -v '^Written by' "$work/size.md") > "$work/out.log"; then ok "identical except the Written by / Run date line"; else ko "the rerun differs"; fi

step "TW-10: nothing under cpp/src, cpp/include or cpp/embedded changed in this loop"
if [ -z "$(git diff --stat 131fc26 HEAD -- cpp/src cpp/include cpp/embedded)" ]; then ok "no change since the loop 45 close (131fc26)"; else git diff --stat 131fc26 HEAD -- cpp/src cpp/include cpp/embedded > "$work/out.log"; ko "core files changed"; fi

step "Loop 46 reports: plan, retro, structure snapshot, 15 lessons"
if [ -f _docs/loops/loop46/plan46.md ] && [ -f _docs/06_metrics/retro_2026-10-20_loop46.md ] && [ -f _docs/06_metrics/structure_2026-10-20_loop46.md ] && [ "$(grep -c '^- \[' _docs/LESSONS.md)" -eq 15 ]; then ok "plan46, retro, structure, 15 lessons"; else ko "a report is missing or LESSONS.md is not 15 entries"; fi

step "Nothing is released: no tag holds HEAD"
if [ -z "$(git tag --points-at HEAD)" ]; then ok "no tag at $(git rev-parse --short HEAD)"; else ko "tag at HEAD: $(git tag --points-at HEAD | tr '\n' ' ')"; fi

echo "$passed/$N steps passed"
[ "$passed" -eq "$N" ]
```
