#!/usr/bin/env bash
# Loop 49 smoke (C++ raw memo pin; AZ-2748). One line per step: [n/N] title, then PASS (Ns) <result> or FAIL
# with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=5 n=0 passed=0
base=1cbc568   # the intake commit of loop 49
export PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "No application source is dirty"
dirty="$(git status --porcelain | grep -vE ' (_docs/|test-results/)' || true)"
if [ -z "$dirty" ]; then ok "no dirty path outside _docs/ at $(git rev-parse --short HEAD)"; else printf '%s\n' "$dirty" > "$work/out.log"; ko "dirty application files"; fi

step "AZ-2748 scope: since the intake commit only the C++ repeat test changed outside _docs/"
chg="$(git diff --name-only "$base" HEAD -- . ':(exclude)_docs' | sort | tr '\n' ' ')"
if [ "$chg" = "cpp/tests/core/text_repeat_host_tests.cpp " ]; then ok "$chg"; else echo "$chg" > "$work/out.log"; ko "unexpected changed files"; fi

step "AZ-2748 AC-1: the cpp stage (host make test) passes"
if PACKBIN_CXX_SYSROOT="$PACKBIN_CXX_SYSROOT" limit 900 scripts/loop-tests.sh --only cpp < /dev/null > "$work/out.log" 2>&1 && grep -q 'STAGE cpp: PASS' "$work/out.log"; then ok "$(grep '^RESULT' "$work/out.log" | tail -1 | cut -c1-70)"; else ko "the cpp stage failed"; fi

step "AZ-2748 AC-2: with forget_raw dropped after the compact field the new test fails (copy of cpp/, repo untouched)"
cp -R cpp "$work/cpp" && rm -rf "$work/cpp/build"
python3 - "$work/cpp/src/core/text_encode.hpp" <<'PY' || { echo "mutation anchor not found" > "$work/out.log"; }
import sys
p = sys.argv[1]; s = open(p).read()
a = "        write_compact(p, size, bits, start, s, len, chars, costs);\n      forget_raw(scratch);\n"
assert a in s
open(p, "w").write(s.replace(a, "        write_compact(p, size, bits, start, s, len, chars, costs);\n"))
PY
if [ ! -f "$work/out.log" ]; then
  limit 900 make -C "$work/cpp" test < /dev/null > "$work/mut.log" 2>&1
  if grep -q 'FAIL: AC-2 a compact field after a raw one clears the memo' "$work/mut.log" && grep -q 'FAIL: AC-2 a compact field clears a stale memo' "$work/mut.log" && ! grep -q 'FAIL: AC-1' "$work/mut.log"; then
    ok "both new checks fail on the mutant, nothing else does"
  else cp "$work/mut.log" "$work/out.log"; ko "the mutant was not caught"; fi
else ko "could not build the mutant"; fi

step "AZ-2748 AC-3: gcc:16 container run of make test passes"
make -C cpp clean > /dev/null 2>&1
if limit 900 docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test < /dev/null > "$work/out.log" 2>&1 && grep -q 'all tests passed' "$work/out.log"; then ok "gcc:16: all tests passed"; else ko "gcc:16 make test failed"; fi
make -C cpp clean > /dev/null 2>&1

printf '\nRESULT %d of %d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
