# Loop 42 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. AZ-2713 AC-1 and AC-2: Python and TypeScript refuse out-of-order and repeated keys (the other six in step 2)
- [x] 4. AZ-2713 AC-3: C++ unpacks 65,535 keys at most 1 s (bound `Array` and unbound; the probe)
- [x] 5. AZ-2713 AC-4: text vectors and the shared hostile cases still pass
- [x] 6. AZ-2722: Python and TypeScript refuse a wrong payload type before the receive index moves
- [x] 7. The contract `compact-text.md` states the ascending-key rule
- [x] 8. No source file this loop touched is over 500 lines
- [x] 9. Nothing is released: no tag holds HEAD

## Result

Agent run 2026-10-19 at `b427967` (owner rule 2026-10-12 in `deployment_procedures.md`): **9/9 steps passed** on the second run. The first run was 8/9: step 11 ran 12 stages green (csharp and python only on the serial retry) and Go failed twice on a timing check unrelated to dict keys (`TestAC3RaisedSlotLimitUnpacksTheOldWorstPacketAndTheDefaultRefusesIt`, the refusal took 1.14 s of 1 s under `-race`, at a load average of 27 to 30 from other sessions on the host); Go alone passed (`go test -race`, 79 s) and `scripts/loop-tests.sh` re-ran only Go: pass (183 s). The second smoke run then found every stage stamped at HEAD. Step 11 first run: 1677 s, ring 336 s, publish gate 419 s. Cortex-M4F: flash 7,920 B of 8,192, stack 504 B of 512 (embedded stage, `b427967` era, 12 s of the cpp-embedded-arm stage).

## For the operator

- The first `v*` tag, F44 and the `go/v*` tag are yours.
- `/feature-assess`, `/security` follow-up and the retrospective are yours to run.

## Script (`bash smoke42.sh`)

```bash
#!/usr/bin/env bash
# Loop 42 smoke (strictly ascending dict keys, AZ-2713; loop 41 Lows, AZ-2722). One line per step: [n/N] title,
# then PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=9 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "AC-1 and AC-2: Python and TypeScript refuse out-of-order and repeated dict keys"
if python/.venv/bin/python -m pytest python/tests/test_dict_key_order.py -v --tb=short -p no:cacheprovider < /dev/null > "$work/out.log" 2>&1 \
  && (cd typescript && node --test tests/dict-key-order.test.ts < /dev/null >> "$work/out.log" 2>&1) && grep -q '^# fail 0' "$work/out.log"; then ok "$(grep -E 'passed|^# pass' "$work/out.log" | tr '\n' ' ')"; else ko "a dict key order test failed"; fi

step "AC-3: C++ unpacks 65,535 ascending keys in at most 1 s (probe dict-quad, -O2)"
if bash fixtures/hostile/fuzz/cpp/build_cpp.sh "$repo" fixtures/hostile/fuzz/cpp "$work" o2 < /dev/null > "$work/out.log" 2>&1 \
  && "$work/probe_o2" dict-quad 65535 < /dev/null >> "$work/out.log" 2>&1 \
  && awk '/^mode=dict-quad/ { for (i = 1; i <= NF; i++) if ($i ~ /^seconds=/) { split($i, a, "="); if (a[2] + 0 <= 1.0 && /ok=1/) good = 1 } } END { exit !good }' "$work/out.log"; then ok "$(grep '^mode=dict-quad' "$work/out.log" | cut -c1-110)"; else ko "the C++ probe is slow or refused the packet"; fi

step "AC-4: text vectors and the shared hostile cases"
if bash fixtures/text/check-vectors.sh < /dev/null > "$work/out.log" 2>&1 && bash fixtures/hostile/check-cases.sh < /dev/null >> "$work/out.log" 2>&1; then ok "$(tail -2 "$work/out.log" | tr '\n' ' ')"; else ko "a fixture check failed"; fi

step "AZ-2722: a wrong payload type leaves the Python and TypeScript receive index alone"
if python/.venv/bin/python -m pytest python/tests/test_session_payload_type.py -v --tb=short -p no:cacheprovider < /dev/null > "$work/out.log" 2>&1 \
  && (cd typescript && node --test tests/session-payload-type.test.ts < /dev/null >> "$work/out.log" 2>&1) && grep -q '^# fail 0' "$work/out.log"; then ok "$(grep -E 'passed|^# pass' "$work/out.log" | tr '\n' ' ')"; else ko "a payload type test failed"; fi

step "The contract states the ascending-key rule"
if grep -q 'strictly greater than the key before it' _docs/02_document/contracts/library/compact-text.md; then ok "compact-text.md invariants"; else ko "the contract sentence is missing"; fi

step "No source file this loop touched is over 500 lines"
long="$(git diff --name-only fc87bc1 HEAD | grep -vE '^_docs/|\.md$|\.txt$' | while read -r f; do [ -f "$f" ] && wc -l < "$f" | awk -v f="$f" '$1 > 500 {print $1, f}'; done)"
if [ -z "$long" ]; then ok "none over 500 lines"; else ko "$long"; fi

step "Nothing is released: no tag holds HEAD"
if [ -z "$(git tag --contains HEAD)" ]; then ok "no tag"; else ko "a tag holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
