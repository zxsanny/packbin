#!/usr/bin/env bash
set -uo pipefail

lang="${1:?language}"
root="${SRC_ROOT:-.}"
fixture="${FIXTURE:-$root/fixtures/golden.hex}"
results="${TEST_RESULTS:-$root/test-results}"
ok=0

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
      run dotnet test "$root/csharp" -v n --nologo
    fi
    ;;
  typescript)
    if [ -f "$root/typescript/package.json" ]; then
      run bash -lc "cd '$root/typescript' && npm test"
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

mkdir -p "$results"
line="$lang,$ok"
if command -v flock >/dev/null 2>&1; then
  flock "$results/report.lock" sh -c "printf '%s\n' '$line' >> '$results/report.csv'"
else
  printf '%s\n' "$line" >> "$results/report.csv"
fi
exit "$ok"
