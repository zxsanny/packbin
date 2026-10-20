# Loop 47 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. AZ-2744 AC-2: no touched ring file is over 500 lines (`language-pair.sh` 452)
- [x] 4. AZ-2744 AC-1: the 340 `handoff` rows are the same, in the same order, as before the split
- [x] 5. AZ-2744 AC-3/AC-4: the wiring tests, the runner-split test, `ring-ecc.test.sh` and `ring-prepare.test.sh` exit 0
- [x] 6. AZ-2745: `TextConcurrencyTests` is in the `swift_sanitized` step and `run-suite.test.sh` (Swift cases) exits 0
- [x] 7. No package source changed in loop 47; no tag holds HEAD

## Result

Agent run 2026-10-20 at `85a4714` (owner rule 2026-10-12 in `deployment_procedures.md`): **7/7 steps passed**. Step 11 ran all 13 stages (the `run-suite.sh` change touches every language): 13 passed, 0 failed, 1,704 s (scaffold 992 s, Swift 1,076 s, ring 72 s, publish gate 376 s; host load 10 to 38, one pause of the heartbeat between 247 s and 945 s with the logs growing again after). The first smoke run printed 7/8 because the script counted 8 steps for 7 written; the count was fixed and the script re-run: 7/7. AZ-2745 AC-4 (agent worker, local): `swift test --sanitize=thread --filter '\.TextConcurrencyTests/'` passed, 0 races, 2.7 s for the test.

## For the operator

- The first `v*` tag, F44 and the `go/v*` tag are yours; CS-D5 waits for the 100 to 200 real messages.
- Jira: AZ-2744 and AZ-2745 are In Testing (no retrospective this loop); epic AZ-2645 stays open for AZ-2742.
- The CI time of the ring job and of the Swift sanitized step is read after the push (AZ-2745 AC-5).

## Script (`bash smoke47.sh`)

```bash
#!/usr/bin/env bash
# Loop 47 smoke (ring runner split and Swift TSan; AZ-2744, AZ-2745). One line per step: [n/N] title,
# then PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=7 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "No application source is dirty at the close"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" limit 3600 scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "AZ-2744 AC-2: no touched ring file is over 500 lines"
big=""
for f in .github/workflows/language-pair.sh .github/workflows/ring-lib.sh .github/workflows/ring-lib.test.sh .github/workflows/ring-wiring.test.sh .github/workflows/ring-wiring-swift.test.sh .github/workflows/ring-wiring-session-ecc.test.sh .github/workflows/ring-ecc.sh .github/workflows/ring-prepare.test.sh; do
  l="$(wc -l < "$f" | tr -d ' ')"; [ "$l" -le 500 ] || big="$big $f=$l"
done
if [ -z "$big" ]; then ok "language-pair.sh $(wc -l < .github/workflows/language-pair.sh | tr -d ' ') lines, all eight files at most 500"; else echo "over:$big" > "$work/out.log"; ko "a ring file is over 500 lines"; fi

step "AZ-2744 AC-1: the ring rows are the same as before the split (340 handoff rows, same order)"
git show 75f03d1:.github/workflows/language-pair.sh | grep -E '^handoff ' > "$work/before.txt"
grep -E '^handoff ' .github/workflows/language-pair.sh > "$work/after.txt"
if [ "$(wc -l < "$work/after.txt" | tr -d ' ')" -eq 340 ] && diff "$work/before.txt" "$work/after.txt" > "$work/out.log"; then ok "340 handoff rows, identical to $(git rev-parse --short 75f03d1)"; else ko "the handoff rows differ"; fi

step "AZ-2744 AC-3/AC-4: the wiring tests, the runner-split test, ring-ecc.test and ring-prepare.test"
rc=0
for t in ring-wiring ring-wiring-swift ring-wiring-session-ecc ring-lib ring-ecc ring-prepare; do
  PATH="/opt/homebrew/bin:$PATH" limit 900 bash ".github/workflows/$t.test.sh" < /dev/null >> "$work/out.log" 2>&1 || { rc=1; echo "FAILED: $t" >> "$work/out.log"; }
done
if [ "$rc" -eq 0 ]; then ok "six scripts exit 0"; else ko "a wiring test failed"; fi

step "AZ-2745: TextConcurrencyTests in the swift_sanitized step (suite check, guard exemption, filter) and its tests"
if grep -q 'for suite in ConcurrencyTests TextConcurrencyTests SessionTests SessionHostileTests' .github/workflows/run-suite.sh \
  && grep -q "TextConcurrency|Session|SessionHostile" .github/workflows/run-suite.sh && grep -q "filter '\\\\.TextConcurrencyTests/'" .github/workflows/run-suite.sh \
  && PATH="/opt/homebrew/bin:$PATH" limit 900 bash .github/workflows/run-suite.test.sh < /dev/null > "$work/out.log" 2>&1; then ok "script strings in place; run-suite.test.sh (with the Swift cases) exit 0"; else ko "the step lacks the suite or run-suite.test.sh failed"; fi

step "Nothing under cpp/src, cpp/include, cpp/embedded or any package source changed; nothing is released"
if [ -z "$(git diff --name-only 75f03d1~1 HEAD -- cpp/src cpp/include cpp/embedded swift/Sources python/src typescript/src)" ] && [ -z "$(git tag --points-at HEAD)" ]; then ok "no package source change in loop 47; no tag at HEAD"; else git diff --name-only 75f03d1~1 HEAD -- cpp/src cpp/include cpp/embedded swift/Sources python/src typescript/src > "$work/out.log"; ko "a package source changed or a tag holds HEAD"; fi

echo "$passed/$N steps passed"
[ "$passed" -eq "$N" ]
```
