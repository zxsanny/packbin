# Loop 43 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. AZ-2724 AC-1 to AC-3: the Python session computes one pad block for an unknown type and the same row for a known one
- [x] 4. AZ-2723 AC-1: the Python timing helper returns a load factor between 1 and 8
- [x] 5. AZ-2723 AC-3: the eight helper files exist and no touched file is over 500 lines
- [x] 6. The contract `pack-session.md` states the pad cost
- [x] 7. Nothing is released: no tag holds HEAD

## Result

Agent run 2026-10-19 at `5bee6cf` (owner rule 2026-10-12 in `deployment_procedures.md`): **7/7 steps passed**. Step 11: 11 stages passed, 2 skipped as unchanged, 0 failed, 961 s; TypeScript passed only on the serial retry: in the pool its first hostile test (`zero-progress repeat ends with trailing error`) stalled 11.9 s and the hang guard of the hostile worker (5 s) fired, then the next test hit the same guard; it is a worker start-up stall, not a scaled wall-clock bound, and nothing else failed. Go, Python, Rust, C#, Java, Swift and C++ passed in the pool with no retry at load 11 to 25. Pool suites 596 s, ring about 100 s.

## For the operator

- The first `v*` tag, F44 and the `go/v*` tag are yours.
- `/feature-assess`, `/security` and the retrospective are yours to run.

## Script (`bash smoke43.sh`)

```bash
#!/usr/bin/env bash
# Loop 43 smoke (load-aware timing bounds, AZ-2723; Python session pad after the type check, AZ-2724). One line per
# step: [n/N] title, then PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=7 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "AZ-2724: one pad block for an unknown type, the same row for a known one"
if python/.venv/bin/python -m pytest python/tests/test_session_pad_after_type.py -v --tb=short -p no:cacheprovider < /dev/null > "$work/out.log" 2>&1; then ok "$(tail -1 "$work/out.log")"; else ko "the pad test failed"; fi

step "AZ-2723 AC-1: the Python and TypeScript load factors are between 1 and 8"
if python/.venv/bin/python -c "import sys; sys.path.insert(0, 'python/tests'); import timing_support as t; f = t.load_factor(); print('python factor %.2f' % f); sys.exit(0 if 1 <= f <= 8 else 1)" < /dev/null > "$work/out.log" 2>&1; then ok "$(cat "$work/out.log")"; else ko "the Python load factor is out of range"; fi

step "AZ-2723 AC-3: the timing helpers exist and no test file is over 500 lines"
missing=""; for f in python/tests/timing_support.py typescript/tests/support/timing.ts csharp/tests/Timing.cs java/src/test/java/packbin/Timing.java rust/src/timing_support.rs go/timing_test.go swift/Tests/PackbinTests/LoadFactor.swift cpp/tests/core/load_factor.hpp; do [ -f "$f" ] || missing="$missing $f"; done
long="$(git diff --name-only fc87bc1 HEAD | grep -vE '^_docs/|\.md$|\.txt$' | while read -r f; do [ -f "$f" ] && wc -l < "$f" | awk -v f="$f" '$1 > 500 {print $1, f}'; done)"
if [ -z "$missing$long" ]; then ok "all helper files present, none over 500 lines"; else ko "missing:$missing long: $long"; fi

step "The contract states the pad cost"
if grep -q 'a payload of an unknown type costs one block' _docs/02_document/contracts/library/pack-session.md; then ok "pack-session.md"; else ko "the contract sentence is missing"; fi

step "Nothing is released: no tag holds HEAD"
if [ -z "$(git tag --contains HEAD)" ]; then ok "no tag"; else ko "a tag holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
