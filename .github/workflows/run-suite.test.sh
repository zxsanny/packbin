#!/usr/bin/env bash
# run-suite.sh python must fail with a message naming the venv when the venv cannot import pytest,
# and must run pytest when it can. The venvs here are fakes, so no network and no real pytest.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/run-suite-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
fail=0

mkdir -p "$work/src/python/tests" "$work/src/fixtures"
: > "$work/src/python/pyproject.toml"
cp "$repo/fixtures/golden.hex" "$work/src/fixtures/golden.hex"

make_venv() {
  local dir="$1" body="$2"
  mkdir -p "$dir/bin"
  : > "$dir/bin/pytest"
  chmod +x "$dir/bin/pytest"
  printf '#!/bin/sh\n%s\n' "$body" > "$dir/bin/python"
  chmod +x "$dir/bin/python"
}

run_suite() {
  SRC_ROOT="$work/src" FIXTURE="$work/src/fixtures/golden.hex" TEST_RESULTS="$work/results" \
    PACKBIN_PYTEST_VENV="$1" perl -e 'alarm 60; exec @ARGV' -- bash "$here/run-suite.sh" python </dev/null 2>&1
}

make_venv "$work/broken" 'exit 127'
out="$(run_suite "$work/broken")"
code=$?
if [ "$code" -eq 0 ]; then echo "FAIL: a broken venv passed"; fail=1; fi
case "$out" in
  *"$work/broken is unusable"*"rm -rf $work/broken"*) ;;
  *) echo "FAIL: no message naming the broken venv and the rebuild command"; echo "$out"; fail=1 ;;
esac

make_venv "$work/good" 'exit 0'
out="$(run_suite "$work/good")"
code=$?
if [ "$code" -ne 0 ]; then echo "FAIL: a usable venv failed (exit $code)"; echo "$out"; fail=1; fi

if [ "$fail" -eq 0 ]; then echo "run-suite.test.sh: all checks passed"; fi
exit "$fail"
