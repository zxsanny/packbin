# Loop 40 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. AZ-2704 AC-1: a closed TypeScript session answers not-open before a duplicate type (C# in step 2)
- [x] 4. AZ-2704 AC-2 and AC-3: Python refuses a duplicate before a parity mix and a bad limit (Java, Rust, Swift, Go in step 2)
- [x] 5. AZ-2704 AC-2 and AC-4: Rust `NoHandlers` spends no position; `parity()` is required (compile-fail doc test)
- [x] 6. The contract `message-ecc.md` states the one order
- [x] 7. No source file this loop touched is over 500 lines
- [x] 8. Nothing is released: no tag holds HEAD

## Result

Agent run 2026-10-19 at `01276b7` (owner rule 2026-10-12 in `deployment_procedures.md`): **8/8 steps passed**. Step 11 ran at `01276b7`: 10 passed, 3 skipped as unchanged (cpp, scaffold, cpp-embedded-arm), 0 failed, 1194 s. Go, Rust and Python passed only on the serial retry: in the pool each failed one timing check alone, at a load average of 45 to 52 (Go `TestACTextLoneStringUnderTimesIsParsedOnce` 510 ms of 500 ms, Rust debug `nfr_round_trips_under_one_second` 1.68 s of 1 s, Python EC-13 1.09 s of 1.0 s); no logic test failed. Ring 84 s, publish gate 304 s.

## For the operator

- The first `v*` tag, F44 and the `go/v*` tag are yours.
- `/feature-assess`, `/security` (AZ-2666) and the retrospective for loops 35 to 40 are yours to run.

## Script (`bash smoke40.sh`)

```bash
#!/usr/bin/env bash
# Loop 40 smoke (one check order for dispatch calls, AZ-2704): smoke40.sh. One line per step: [n/N] title, then
# PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=8 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "AC-1: a closed TypeScript session answers not-open before a duplicate type"
if (cd typescript && node --test tests/ecc-dispatch-order.test.ts < /dev/null > "$work/out.log" 2>&1) && grep -q '^# fail 0' "$work/out.log"; then ok "$(grep '^# pass' "$work/out.log")"; else ko "the TypeScript dispatch-order test failed"; fi

step "AC-2 and AC-3: Python duplicate before the parity mix and the limit"
if python/.venv/bin/python -m pytest python/tests/test_ecc_dispatch_order.py -v --tb=short -p no:cacheprovider < /dev/null > "$work/out.log" 2>&1; then ok "$(tail -1 "$work/out.log")"; else ko "the Python dispatch-order test failed"; fi

step "AC-2 and AC-4: Rust NoHandlers and a required parity() (compile-fail doc test)"
if (cd rust && cargo test --doc DispatchHandler < /dev/null > "$work/out.log" 2>&1 && grep -q 'compile fail ... ok' "$work/out.log" \
  && cargo test --test ecc_session_dispatch_tests empty_handler_list < /dev/null >> "$work/out.log" 2>&1); then ok "doc tests and the empty-list test pass"; else ko "a Rust check failed"; fi

step "The contract states the one order"
if grep -q 'run in one order in every package' _docs/02_document/contracts/library/message-ecc.md; then ok "message-ecc.md Dispatch row"; else ko "the contract sentence is missing"; fi

step "No source file this loop touched is over 500 lines"
long="$(git diff --name-only 75b1d39 HEAD | grep -vE '^_docs/|\.md$' | while read -r f; do [ -f "$f" ] && wc -l < "$f" | awk -v f="$f" '$1 > 500 {print $1, f}'; done)"
if [ -z "$long" ]; then ok "none over 500 lines"; else ko "$long"; fi

step "Nothing is released: no tag holds HEAD"
if [ -z "$(git tag --contains HEAD)" ]; then ok "no tag"; else ko "a tag holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
