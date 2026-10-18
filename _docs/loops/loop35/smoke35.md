# Loop 35 smoke — checks

LOCAL_URL: none (a library: the proof is the test stages, the vectors and the size bounds; no UI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD (`scripts/loop-tests.sh`): none failed
- [x] 3. The compact text vectors file is re-derived by the reference and every mutant is refused
- [x] 4. All eight packages hold exactly the emitted tables file
- [x] 5. `tables.json` is reproduced byte for byte from the recorded corpus
- [x] 6. Every size bound of the held-out report holds; CS-13 holds on every vector
- [x] 7. The position record is still the 13-byte golden packet
- [x] 8. No tag contains the loop and `origin/main` does not hold HEAD

## Result

Agent run 2026-10-18 at `1af9cf0` (owner rule 2026-10-12 in `deployment_procedures.md`): **8/8 steps passed**. Smoke: PASS. Step 2 ran the scaffold stage (261 s) and printed 12 stages as skipped because nothing they cover changed since the commits where they passed (`a9cabf1` for C#, the ring and the language suites at the second step 11 run, `f553ef9` for the ARM stage and the publish gate). Earlier: step 11 at `f553ef9` passed 11 of 13 stages (TypeScript only on its serial retry); C# and the ring failed on test data and the missed `dictgroup` ring bytes, fixed in `a9cabf1`; the second run passed 9 stages with the scaffold stage only on its serial retry (a load-sensitive build-timing check in `ring-prepare.test.sh`).

## For the operator

- `main` was not pushed and no tag exists: you asked for the `dev` push only, so the `loop_end_merge: main` step of `ci_cd_pipeline.md` was not executed (same as loops 33 and 34).
- Skipped by your decision for this loop: `/feature-assess`, the security audit and the retrospective (carried to loop 36 in `handoff36.md`).
- The CI run on `dev` is the proof of the timing bounds; its result is in `record35.md`.

## Script (run with the corpus directory: `bash smoke35.sh <dir>`)

```bash
#!/usr/bin/env bash
# Loop 35 smoke (compact strings, epic AZ-2645): smoke35.sh <corpus dir with ukr/rus/eng_sentences.tsv>. One line per
# step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason. No network; the rest comes from the tree.
set -uo pipefail
corpus="${1:?corpus dir}"
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=8 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed, skips only for unchanged stages"
if scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "Compact text vectors: 418 rows re-derived by the reference, every mutant refused"
if fixtures/text/check-vectors.test.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^check-vectors:' "$work/out.log" | head -1)"; else ko "check-vectors.test.sh failed"; fi

step "Every package holds exactly the emitted tables file (8 of 8) and the checker refuses a changed or missing file"
if scripts/text/check-emitted.sh < /dev/null > "$work/out.log" 2>&1 && scripts/text/check-emitted.test.sh < /dev/null >> "$work/out.log" 2>&1; then ok "$(grep -c ' ok ' "$work/out.log") ok lines"; else ko "check-emitted failed"; fi

step "tables.json is reproduced byte for byte from the recorded corpus (CS-1/2/14 recipe)"
if PACKBIN_TEXT_CORPUS="$corpus" python3 scripts/text/train_tables.py --workers 4 --check < /dev/null > "$work/out.log" 2> "$work/err.log"; then ok "$(tail -1 "$work/out.log")"; else cp "$work/err.log" "$work/out.log"; ko "retraining differs"; fi

step "Sizes: every bound of tables.report.md holds, and CS-13 holds on every vector"
if ! grep -q 'OVER' fixtures/text/tables.report.md && python3 scripts/text/size_report.py < /dev/null > "$work/out.log" 2>&1 && grep -q 'PASS$' "$work/out.log"; then ok "$(grep -c '| ok |' fixtures/text/tables.report.md) report rows ok; $(tail -1 "$work/out.log" | cut -c1-90)"; else ko "a size bound fails"; fi

step "A packet without strings is unchanged: the position record is still 13 bytes"
if grep -qx 4001000065cd1d00a3e1110100 fixtures/golden.hex && [ "$(tr -d '\n' < fixtures/golden.hex | wc -c | tr -d ' ')" = 26 ]; then ok "golden.hex is the 13-byte position packet"; else ko "golden.hex changed"; fi

step "Nothing is released: no tag contains the loop, and origin/main does not hold HEAD"
if [ -z "$(git tag --contains HEAD)" ] && ! git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then ok "no tag, main not pushed"; else ko "a tag or main holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
