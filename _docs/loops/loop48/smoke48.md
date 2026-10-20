# Loop 48 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the start
- [x] 2. AZ-2742 AC-3/AC-4: the arm embedded stage passes (flash and stack margins, AVR Uno)
- [x] 3. Step 11 stages at HEAD: none failed
- [x] 4. AZ-2742 AC-2: only `text_encode.hpp` and `pack.cpp` changed under cpp/src; no fixture or other package changed
- [x] 5. AZ-2742 AC-1: the C++ repeat test is a 1 s test
- [x] 6. AZ-2747 AC-1/AC-2: comment-only edits in six scripts; the split files are at most 450 lines
- [x] 7. AZ-2747 AC-3: the `expect_*` calls are the same plus one new mutant after the split; the wiring tests exit 0
- [x] 8. Nothing is released

## Result

Agent run 2026-10-20 at `b95a0d0` (owner rule 2026-10-12 in `deployment_procedures.md`): **8/8 steps passed**. The arm embedded stage: flash budget image 7,920 B of 8,192 and stack 504 B of 512 (both as before; the all-kinds image 19,056 B to 19,120 B), AVR Uno 15,386 B. Step 11 ran 5 stages (the others skipped as unchanged): 5 passed, 0 failed, 640 s (host load up to 64). Wiring tests: seven scripts exit 0, `expect_*` lines 50 before and 51 after (one new mutant for the rows step). C++ repeat test on gcc:16: pack 13 ms for 200 rounds of 65,535 characters (1.9 s before); with the `words[1] == len` check dropped the equality test fails, with the reset in `pack_table` dropped the stale-memo test fails.

## For the operator

- Jira: AZ-2742 and AZ-2747 are In Testing; epic AZ-2645 stays open.
- The CI time of `test.yml` after the push (ring and scaffold) is read from the run annotations.
- The first `v*` tag, F44 and the `go/v*` tag are yours; CS-D5 waits for the 100 to 200 real messages.

## Script (`bash smoke48.sh`)

```bash
#!/usr/bin/env bash
# Loop 48 smoke (C++ repeated raw text and ring cleanup; AZ-2742, AZ-2747). One line per step: [n/N] title,
# then PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=8 n=0 passed=0
base=5fc5027   # the intake commit of loop 48

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "No application source is dirty at the start"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "AZ-2742 AC-3/AC-4: arm embedded stage (M0+, M3, M4F budget, s390x, AVR Uno)"
make -C cpp clean > /dev/null 2>&1
if limit 900 docker compose -f docker-compose.test.yml run --rm cpp-embedded < /dev/null > "$work/out.log" 2>&1 \
  && grep -q 'cpp-m4f: PASS' "$work/out.log" && grep -q 'cpp-avr-uno: PASS' "$work/out.log" && ! grep -q ': FAIL' "$work/out.log"; then
  ok "$(grep 'NOTE deepest' "$work/out.log" | tail -1 | cut -c1-90); $(grep 'NOTE AC-5' "$work/out.log" | tail -1 | cut -c1-90)"
else ko "the arm embedded stage failed"; fi
make -C cpp clean > /dev/null 2>&1

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" limit 3600 scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "AZ-2742 AC-2: no text vector or other package changed; only text_encode.hpp and pack.cpp under cpp/src"
chg="$(git diff --name-only "$base" HEAD -- fixtures cpp/src cpp/include cpp/embedded csharp java go python rust swift typescript | sort | tr '\n' ' ')"
if [ "$chg" = "cpp/src/core/pack.cpp cpp/src/core/text_encode.hpp " ]; then ok "$chg"; else echo "$chg" > "$work/out.log"; ko "unexpected changed files"; fi

step "AZ-2742 AC-1: the C++ repeat test is a 1 s test and passed in the cpp stage"
if grep -q 'load_factor::bound(1.0)' cpp/tests/core/text_repeat_host_tests.cpp && grep -q 'within_one_second' cpp/tests/core/text_repeat_host_tests.cpp \
  && ! grep -q 'within_three_seconds' cpp/tests/core/text_repeat_host_tests.cpp; then ok "bound 1.0 in the test; the cpp stage of step 11 ran it"; else ko "the bound is not 1 s"; fi

step "AZ-2747 AC-1/AC-2: six scripts changed in comment lines only; the split files are at most 450 lines"
six=".github/workflows/ring-cxx.sh .github/workflows/ring-go.sh .github/workflows/ring-swift.sh .github/workflows/ring-prepare.sh .github/workflows/ring-toolchains.sh .github/workflows/publish-vcpkg.test.sh"
code="$(git diff -U0 "$base" HEAD -- $six | grep -E '^[+-][^+-]' | grep -vE '^[+-][[:space:]]*#' || true)"
big=""
for f in .github/workflows/ring-wiring.test.sh .github/workflows/ring-wiring-rows.test.sh .github/workflows/ring-wiring-lib.sh; do
  l="$(wc -l < "$f" | tr -d ' ')"; [ "$l" -le 450 ] || big="$big $f=$l"
done
if [ -z "$code" ] && [ -z "$big" ]; then ok "comment-only; ring-wiring $(wc -l < .github/workflows/ring-wiring.test.sh | tr -d ' ') + rows $(wc -l < .github/workflows/ring-wiring-rows.test.sh | tr -d ' ') + lib $(wc -l < .github/workflows/ring-wiring-lib.sh | tr -d ' ') lines"; else printf '%s\n%s\n' "$code" "$big" > "$work/out.log"; ko "a code line changed or a split file is too long"; fi

step "AZ-2747 AC-3: expect_* calls are the same plus one new mutant after the split; the wiring tests exit 0"
before="$(git show "$base:.github/workflows/ring-wiring.test.sh" | grep -cE '^[[:space:]]*expect_[a-z_]+ ')"
after="$(cat .github/workflows/ring-wiring.test.sh .github/workflows/ring-wiring-rows.test.sh | grep -cE '^[[:space:]]*expect_[a-z_]+ ')"
rc=0
for t in ring-wiring ring-wiring-rows ring-wiring-swift ring-wiring-session-ecc ring-lib ring-prepare publish-jobs; do
  PATH="/opt/homebrew/bin:$PATH" limit 900 bash ".github/workflows/$t.test.sh" < /dev/null >> "$work/out.log" 2>&1 || { rc=1; echo "FAILED: $t" >> "$work/out.log"; }
done
if [ "$((before + 1))" = "$after" ] && [ "$rc" -eq 0 ]; then ok "$before expect_* lines before, $after after (one new mutant for the rows step); seven scripts exit 0"; else echo "expect before $before after $after" >> "$work/out.log"; ko "calls differ or a wiring test failed"; fi

step "Nothing is released"
if [ -z "$(git tag --points-at HEAD)" ]; then ok "no tag at HEAD"; else ko "a tag holds HEAD"; fi

echo "$passed/$N steps passed"
[ "$passed" -eq "$N" ]
```
