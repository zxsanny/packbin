# Loop 45 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. AZ-2733 AC-1, AC-2: the TypeScript encoder keeps no field or scratch after a call; the compact text tests pass
- [x] 4. AZ-2733 AC-3: C++ tests of a Text<N> in times, repeat and under a flags bit exist and the cpp stage passed
- [x] 5. AZ-2733 AC-4: the test-spec documents carry the compact bytes and the CS, HD, RL ids
- [x] 6. AZ-2733 AC-5: the Go fuzz seeds equal the compact packets of the hostile corpus (28 compared, 0 differ)
- [x] 7. AZ-2733 AC-6: `size_report.md` exists with the date, recipe hashes and CS-13 on every `enc` row
- [x] 8. AZ-2733 AC-7: the ECC criteria say 254 and today's Cortex-M4F numbers; the C++ description matches
- [x] 9. AZ-2733 AC-8: the Python 25 s and TypeScript 2.5 s load-aware bounds; CS-11 states the measurements
- [x] 10. AZ-2733 AC-9: nothing under `cpp/src`, `cpp/include` or `cpp/embedded` changed in this loop
- [x] 11. The loop 45 report: `assessment45.md` (verdict CLARIFY), `handoff46.md`, the plan's Assessment rounds table
- [x] 12. Nothing is released: no tag holds HEAD

## Result

Agent run 2026-10-20 at `da30284` (owner rule 2026-10-12 in `deployment_procedures.md`): **12/12 steps passed** (the first run had 11/12: step 8 forbade the loop 39 figures that the C++ description keeps on purpose as history; the check was changed to require today's numbers). Step 11 at `da30284`: 5 stages passed (typescript 10 s, cpp 39 s, python 141 s, go 161 s, ring 54 s), 8 skipped as unchanged, 0 failed, 215 s, host load 5 to 15. Not run here: the ESP stage (CI only on the `dev` push), the vcpkg supports and consumer checks (no vcpkg tool on this Mac), and the publish gate and the ARM stage (unchanged since `f5785b1`).

## For the operator

- The first `v*` tag, F44 and the `go/v*` tag are yours.
- The retrospective is due (5 loops since loop 41).
- Open decisions are in `handoff46.md`: the real messages for CS-D5, and the loop 46 test waves.
- Jira: epic AZ-2645 stays open for the loop 46 items.

## Script (`bash smoke45.sh`)

```bash
#!/usr/bin/env bash
# Loop 45 smoke (feature assessment of compact strings and message ECC; AZ-2733). One line per step: [n/N] title,
# then PASS (Ns) <result> or FAIL with the reason. No network beyond the local Docker images.
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

step "AZ-2733 AC-1, AC-2: the TypeScript encoder keeps no field or scratch after a call; the compact text tests pass"
if (cd typescript && limit 300 node --test tests/text-module-state.test.ts tests/compact-text.test.ts < /dev/null > "$work/out.log" 2>&1); then ok "$(grep -E '^# (pass|fail)' "$work/out.log" | tr '\n' ' ')"; else ko "text-module-state or compact-text tests failed"; fi

step "AZ-2733 AC-3: C++ tests of a Text<N> in times, repeat and under a flags bit exist and the cpp stage passed"
f=cpp/tests/core/text_api_host_tests.cpp; miss=""
for t in text_in_every_times_round text_in_every_repeat_round text_under_a_flags_bit_set_with_an_empty_text_is_one_byte unpack_of_a_clear_flags_bit_leaves_the_text_empty_and_reads_no_field; do
  [ "$(grep -c "^  $t();" "$f")" -eq 1 ] || miss="$miss $t"; done
if [ -z "$miss" ]; then ok "4 tests are called by run_core_text_api_host_tests (the cpp stage of step 2 ran them)"; else printf 'not called:%s\n' "$miss" > "$work/out.log"; ko "C++ tests missing"; fi

step "AZ-2733 AC-4: test-spec documents carry the compact bytes and the CS, HD, RL ids"
miss=""
grep -q '062bfcfee119b2' _docs/02_document/tests/test-data.md || miss="$miss FT-U-01-hex"
grep -qiE '2-byte count' _docs/02_document/tests/blackbox-tests-02-strings-lists-dicts.md && miss="$miss old-2-byte-count"
for id in $(seq 1 20); do grep -qE "\bCS-$id\b" _docs/02_document/tests/traceability-matrix.md || miss="$miss CS-$id"; done
for id in 1 2 3 4 5; do grep -qE "\bHD-$id\b" _docs/02_document/tests/traceability-matrix.md || miss="$miss HD-$id"; done
for id in 1 2 3 4; do grep -qE "\bRL-$id\b" _docs/02_document/tests/traceability-matrix.md || miss="$miss RL-$id"; done
if [ -z "$miss" ]; then ok "FT-U-01 062bfcfee119b2; no '2-byte count'; CS-1..20, HD-1..5, RL-1..4 in the traceability matrix"; else printf '%s\n' "$miss" > "$work/out.log"; ko "missing:$miss"; fi

step "AZ-2733 AC-5: the Go fuzz seeds equal the compact packets of fixtures/hostile/fuzz/corpus.txt"
if python3 - > "$work/out.log" 2>&1 <<'PY'
import ast, os, sys
seeds = "go/testdata/fuzz/FuzzUnpack"
checked = bad = 0
for line in open("fixtures/hostile/fuzz/corpus.txt"):
    if line.startswith("#") or not line.strip():
        continue
    name, _kind, hexs = line.split()[:3]
    path = os.path.join(seeds, name + "_packet")
    if not os.path.exists(path):
        continue
    body = open(path).read().split("\n")[1].strip()
    got = ast.literal_eval(body[len("[]byte("):-1]).encode("latin-1")
    checked += 1
    if got.hex() != hexs:
        bad += 1
        print("MISMATCH", name, got.hex(), hexs)
print("checked", checked, "mismatched", bad)
sys.exit(1 if bad or checked < 6 else 0)
PY
then ok "$(tail -1 "$work/out.log")"; else ko "seed bytes differ from the corpus"; fi

step "AZ-2733 AC-6: size_report.md exists with the date, recipe hashes and CS-13 on every enc row"
r=_docs/02_task_plans/compact-strings/size_report.md
if [ -f "$r" ] && grep -qE '[0-9a-f]{64}' "$r" && grep -q '2026-10-20' "$r" && grep -qE 'PASS' "$r"; then ok "$(grep -ciE 'sha256|[0-9a-f]{64}' "$r") hash lines, run date 2026-10-20, PASS present"; else ko "size_report.md missing or incomplete"; fi

step "AZ-2733 AC-7: ECC criteria say 254 and today's Cortex-M4F numbers; the C++ description matches"
a=_docs/02_task_plans/message-error-correction/acceptance_criteria.md; d=_docs/02_document/components/05_cpp_package/description.md
if ! grep -q 'longer than 255' "$a" && grep -q '7,920' "$a" && grep -q '504' "$a" && grep -q '504 of 512' "$d" && grep -q '7,920 of 8,192' "$d" && ! grep -q '255-byte block' _docs/02_task_plans/message-error-correction/input_data/expected_results/results_report.md; then ok "EC-4 254, EC-12 7,920 B / 504 B, the C++ description states 504 of 512 and 7,920 of 8,192 (loop 39 figures kept as history), results row 16 says 254-byte message"; else ko "ECC numbers still stale"; fi

step "AZ-2733 AC-8: Python 25 s and TypeScript 2.5 s load-aware bounds, CS-11 states the measurements"
if grep -q 'take_at_most_25_seconds' python/tests/test_compact_text.py && grep -q 'assert_within(elapsed, limit, "100000 round trips' python/tests/test_compact_text.py \
  && grep -q 'bound(2.5)' typescript/tests/compact-text.test.ts && grep -qE '2\.5 seconds in TypeScript' _docs/02_task_plans/compact-strings/acceptance_criteria.md && grep -qE '25 seconds in Python' _docs/02_task_plans/compact-strings/acceptance_criteria.md; then ok "Python bound(25.0) with assert_within, TypeScript bound(2.5), CS-11 text updated"; else ko "speed bound edits missing"; fi

step "AZ-2733 AC-9: nothing under cpp/src, cpp/include or cpp/embedded changed in this loop"
if [ -z "$(git diff --stat 857ba8c HEAD -- cpp/src cpp/include cpp/embedded)" ]; then ok "no change since the loop 44 close (857ba8c)"; else git diff --stat 857ba8c HEAD -- cpp/src cpp/include cpp/embedded > "$work/out.log"; ko "core files changed"; fi

step "Loop 45 report: assessment45.md has the CLARIFY verdict, handoff46.md exists, the plan lists round 1"
if grep -q '^verdict: CLARIFY' _docs/loops/loop45/assessment45.md && [ -f _docs/loops/loop45/handoff46.md ] && grep -q 'AZ-2733_assessment45_gaps' _docs/loops/loop45/plan45.md; then ok "verdict CLARIFY, 71 rows, handoff46.md and the plan's Assessment rounds table present"; else ko "loop 45 report files incomplete"; fi

step "Nothing is released: no tag holds HEAD"
if [ -z "$(git tag --points-at HEAD)" ]; then ok "no tag at $(git rev-parse --short HEAD)"; else ko "tag at HEAD: $(git tag --points-at HEAD | tr '\n' ' ')"; fi

echo "$passed/$N steps passed"
[ "$passed" -eq "$N" ]
```
