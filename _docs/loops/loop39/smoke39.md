# Loop 39 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. AZ-2694 AC-1: a duplicate type is refused and the receive index stays (Python tests; the other seven packages run in step 2)
- [x] 4. AZ-2694 AC-2: Go, Swift and C++ have a distinct `too_long`; the contract row says so
- [x] 5. AZ-2694 AC-3: a Rust `DispatchHandler` without `parity()` compiles and dispatches
- [x] 6. AZ-2695 AC-2: the C++ description carries 8,132 B and 492 B, no present-tense 8152 or 456
- [x] 7. No source file this loop touched is over 500 lines
- [x] 8. Nothing is released

## Result

Agent run 2026-10-18 at `ad3ddd0` (owner rule 2026-10-12 in `deployment_procedures.md`): **8/8 steps passed**. Step 11 ran every stage at `65bf37d`: the language suites passed (typescript only on the serial retry: `round-scope-cost` ran beside other suites), the arm stage held 8,132 B flash and 492 B stack, and the ring failed once, for a real reason: the Go, Swift and C++ ring drivers (`.github/workflows/drivers`) still mapped the old rounds error to `too_long`; fixed in `ad3ddd0`, the ring then passed (73 s). The publish gate failed once on `publish-go.test.sh` AC-3 (the proxy was asked once in a 3 s window, load average about 50) and passed on the quiet re-run (298 s). Not run locally: the vcpkg supports and consumer checks (no vcpkg tool), the ESP32 and Pico builds with ECC, and the `test.yml` median over two CI runs (AZ-2689 AC-3).

## For the operator

- `main` was not pushed and no tag exists. The first `v*` tag, F44 and the `go/v*` tag are yours.
- `/feature-assess`, `/security` (AZ-2666) and the retrospective for loops 35 to 39 are yours to run.

## Script (`bash smoke39.sh`)

```bash
#!/usr/bin/env bash
# Loop 39 smoke (message ECC review cleanups, AZ-2694 and AZ-2695): smoke39.sh. One line per step: [n/N] title, then
# PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
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

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "AC-1: a duplicate type is refused and the receive index stays (Python)"
if python/.venv/bin/python -m pytest python/tests/test_ecc_dispatch_order.py -v --tb=short < /dev/null > "$work/out.log" 2>&1; then ok "$(tail -1 "$work/out.log")"; else ko "the dispatch-order test failed"; fi

step "AC-2: Go, Swift and C++ have a distinct too_long; the contract says so"
if grep -q 'TooLong' go/errors.go && grep -q 'tooLong' swift/Sources/Packbin/PackbinError.swift && grep -q 'TooLong' cpp/include/packbin/core.hpp \
  && grep -q 'distinct from the rounds' _docs/02_document/contracts/library/message-ecc.md; then ok "TooLong in go, swift, cpp; contract row 'Unpack, longer than 254' updated"; else ko "a package or the contract lacks it"; fi

step "AC-3: a Rust DispatchHandler without parity() compiles and dispatches"
if (cd rust && cargo test --test ecc_session_dispatch_tests a_handler_without_parity < /dev/null > "$work/out.log" 2>&1); then ok "$(grep 'test result' "$work/out.log" | head -1)"; else ko "the Rust default test failed"; fi

step "The C++ description carries the measured numbers"
d=_docs/02_document/components/05_cpp_package/description.md
if sed -n 125,135p "$d" | grep -q '8,132' && sed -n 125,135p "$d" | grep -q '492' && ! sed -n 125,135p "$d" | grep -q 'uses 456 of the 512'; then ok "8,132 B flash and 492 B stack in the present-tense text"; else ko "lines 125 to 135 of the description still carry old numbers"; fi

step "No source file this loop touched is over 500 lines"
long="$(git diff --name-only 7a3bd91 HEAD | grep -vE '^_docs/|\.md$|vectors\.txt|ring-cases\.txt' | while read -r f; do [ -f "$f" ] && wc -l < "$f" | awk -v f="$f" '$1 > 500 {print $1, f}'; done)"
if [ -z "$long" ]; then ok "none over 500 lines"; else ko "$long"; fi

step "Nothing is released: no tag holds HEAD, main is not pushed"
if [ -z "$(git tag --contains HEAD)" ] && ! git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then ok "no tag, main not pushed"; else ko "a tag holds HEAD, or main holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
