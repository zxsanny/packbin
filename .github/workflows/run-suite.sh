#!/usr/bin/env bash
set -uo pipefail

lang="${1:?language}"
root="${SRC_ROOT:-.}"
fixture="${FIXTURE:-$root/fixtures/golden.hex}"
results="${TEST_RESULTS:-$root/test-results}"
ok=0
started=$(date +%s)

grep -qx '4001000065cd1d00a3e1110100' "$fixture" || ok=1

run() {
  if [ "$ok" -ne 0 ]; then
    return
  fi
  "$@" || ok=1
}

case "$lang" in
  csharp)
    shopt -s nullglob
    projects=("$root"/csharp/*.csproj)
    if [ "${#projects[@]}" -gt 0 ]; then
      run env MSBUILDDISABLENODEREUSE=1 dotnet test "$root/csharp" -v n --nologo
    fi
    ;;
  typescript)
    if [ -f "$root/typescript/package.json" ]; then
      run bash -lc "cd '$root/typescript' && if [ ! -f node_modules/typescript/lib/tsc.js ]; then npm ci; fi && npm test"
    fi
    ;;
  python)
    if [ -f "$root/python/pyproject.toml" ]; then
      venv="${PACKBIN_PYTEST_VENV:-/tmp/packbin-pytest}"
      if [ ! -x "$venv/bin/pytest" ]; then
        python -m venv "$venv"
        "$venv/bin/pip" install pytest
      fi
      run "$venv/bin/python" -m pytest -v --tb=short "$root/python/tests"
    fi
    ;;
  rust)
    if [ -f "$root/rust/Cargo.toml" ]; then
      run cargo test --manifest-path "$root/rust/Cargo.toml" -- --nocapture
    fi
    ;;
  cpp)
    if [ -f "$root/cpp/Makefile" ]; then
      run make -C "$root/cpp" test
    fi
    ;;
  java)
    if [ -x "$root/java/test.sh" ] || [ -f "$root/java/test.sh" ]; then
      run bash "$root/java/test.sh"
    fi
    ;;
  *)
    echo "unknown language: $lang" >&2
    ok=1
    ;;
esac

elapsed_ms=$(( ($(date +%s) - started) * 1000 ))
if [ "$ok" -eq 0 ]; then
  result=PASS
  message=
else
  result=FAIL
  message="suite failed"
fi
TEST_RESULTS="$results" SRC_ROOT="$root" bash "$root/.github/workflows/report-row.sh" \
  "$lang" "$lang suite" "$elapsed_ms" "$result" "$message"
exit "$ok"
