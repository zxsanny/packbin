# Loop 36 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [ ] 1. No application source is dirty at the close
- [ ] 2. Step 11 stages at HEAD: none failed
- [ ] 3. HD-1: no module-level text cache in Python or TypeScript
- [ ] 4. HD-3, HD-4: the Rust release and Swift TextSpeedTests steps are in CI and guarded
- [ ] 5. HD-5: the decoder review note, nothing released

## Result

(filled by the run)

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
