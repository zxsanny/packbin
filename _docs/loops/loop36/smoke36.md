# Loop 36 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. HD-1: no module-level text cache in Python or TypeScript
- [x] 4. HD-3, HD-4: the Rust release and Swift TextSpeedTests steps are in CI and guarded
- [x] 5. HD-5: the decoder review note, nothing released

## Result

Agent run 2026-10-18 at `bd9cc89` (owner rule 2026-10-12 in `deployment_procedures.md`): **5/5 steps passed**. Smoke: PASS. Step 2 ran 9 stages (740 s) and printed 4 as skipped because nothing they cover changed since their last pass; the Rust and Swift suites ran in their CI containers, so the new release speed step (Rust) and the `TextSpeedTests` filter (Swift) were exercised.

## For the operator

- `main` was not pushed and no tag exists (`loop_end_merge: main` is not executed: only the `dev` push was asked for).
- AC HD-5 is only partly met: the project `/security` skill is reserved for you, so the note `_docs/05_security/compact_text_decoder_review_loop36.md` is a focused read of the decoders, not the audit. AZ-2666 stays In Progress until you run `/security`.
- `/feature-assess` and the retrospective for loops 35 and 36 are still yours to run.
- The first CI run measures what the Rust release build adds to the `csharp rust` suite job (flagged concern in `problem.md`).

## Script (`bash smoke36.sh`)

```bash
#!/usr/bin/env bash
# Loop 36 smoke (compact text hardening, AZ-2664 to AZ-2666): smoke36.sh. One line per step: [n/N] title, then
# PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=5 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed, skips only for unchanged stages"
if scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "HD-1: no module-level text cache is left in Python or TypeScript"
if ! grep -n '^_last\b' python/src/packbin/_text_encode.py > "$work/out.log" && ! grep -n '^let lastText\|^let lastField' typescript/src/text.ts >> "$work/out.log" && grep -q 'self.text = TextCache()' python/src/packbin/_pack_limits.py && grep -q 'readonly text = new TextCache()' typescript/src/pack-out.ts; then ok "the cache is a field of _PackBudget and PackOut"; else ko "a module-level cache is still there"; fi

step "HD-3 and HD-4: CI runs the string speed test for Rust (release) and Swift (TextSpeedTests)"
if grep -q 'rust_speed' .github/workflows/run-suite.sh && grep -q "\\\\.TextSpeedTests/" .github/workflows/run-suite.sh && bash .github/workflows/run-suite.test.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(tail -1 "$work/out.log")"; else ko "the speed steps or their guard are missing"; fi

step "HD-5: the decoder review note exists and finds no High or Critical issue; nothing is released"
if grep -q 'No High or Critical finding' _docs/05_security/compact_text_decoder_review_loop36.md && [ -z "$(git tag --contains HEAD)" ] && ! git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then ok "note present, no tag, main not pushed"; else ko "note missing, a tag holds HEAD, or main holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
