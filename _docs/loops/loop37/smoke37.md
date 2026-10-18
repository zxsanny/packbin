# Loop 37 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. RL-1: a local Scratch<65535> fails the C++ build, a static one passes
- [x] 4. RL-2: no CompactText test file is over 500 lines
- [x] 5. RL-3: the research bench files are at most 500 lines and the bench imports
- [x] 6. Nothing is released

## Result

Agent run 2026-10-18 at `7963837` (owner rule 2026-10-12 in `deployment_procedures.md`): **6/6 steps passed**. Smoke: PASS. Step 2 printed 13 stages as skipped because the full step 11 had passed at `6a8d273` (6 passed, 7 skipped, 0 failed, 476 s: csharp, cpp, cpp-embedded-arm, ring, ac10, publish-gate) and only docs changed after it. Not run locally: the vcpkg supports and consumer checks (CI runs them).

## For the operator

- `main` was not pushed and no tag exists (`loop_end_merge: main` is not executed: only the `dev` push was asked for).
- `/feature-assess`, `/security` (AZ-2666) and the retrospective for loops 35 to 37 are still yours to run.

## Script (`bash smoke37.sh`)

```bash
#!/usr/bin/env bash
# Loop 37 smoke (review35 Lows, AZ-2674 to AZ-2676): smoke37.sh. One line per step: [n/N] title, then
# PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=6 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed, skips only for unchanged stages"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "RL-1: a local Scratch<65535> fails the C++ build, a static one passes"
if PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" make -C cpp frame-check < /dev/null > "$work/out.log" 2>&1 && grep -q 'rejected, static accepted' "$work/out.log"; then ok "$(tail -1 "$work/out.log")"; else ko "the frame check failed"; fi

step "RL-2: no CompactText test file is over 500 lines"
if [ -z "$(wc -l csharp/tests/CompactText*.cs | grep -v total | awk '$1 > 500')" ]; then ok "$(ls csharp/tests/CompactText*.cs | wc -l | tr -d ' ') files, longest $(wc -l csharp/tests/CompactText*.cs | grep -v total | sort -n | tail -1 | awk '{print $1}') lines"; else ko "a file is over 500 lines"; fi

step "RL-3: the research bench files are at most 500 lines and the bench imports"
cd _docs/02_task_plans/compact-strings/research || exit 1
if [ -z "$(wc -l bench*.py | grep -v total | awk '$1 > 500')" ] && /opt/homebrew/bin/python3.14 -c "import bench" < /dev/null > "$work/out.log" 2>&1 && grep -q 'textfmt' bench_common.py; then ok "4 files, textfmt supplies the alphabets and codes"; else ko "a bench file is long, or the import fails"; fi
cd "$repo" || exit 1

step "Nothing is released: no tag holds HEAD, main is not pushed"
if [ -z "$(git tag --contains HEAD)" ] && ! git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then ok "no tag, main not pushed"; else ko "a tag holds HEAD, or main holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
