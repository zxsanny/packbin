#!/usr/bin/env bash
# run-suite.sh python: fails with a message naming the venv when it cannot import pytest, runs
# `python -m pytest` on a usable venv and passes its exit code on, refuses to clear a directory
# that is not a venv, and builds a missing venv with the pinned pytest. All interpreters are
# fakes that log their arguments, so there is no network and no real pytest.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/run-suite-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
fail=0

bad() { echo "FAIL: $1"; fail=1; }

root="$work/src"
mkdir -p "$root/python/tests" "$root/fixtures" "$root/.github/workflows"
: > "$root/python/pyproject.toml"
cp "$repo/fixtures/golden.hex" "$root/fixtures/golden.hex"
cp "$here/tool-pin.sh" "$here/tool-pins.txt" "$root/.github/workflows/"
cat > "$root/.github/workflows/report-row.sh" <<'ROW'
#!/usr/bin/env bash
echo "report-row $*" >> "${TEST_RESULTS}.rows"
ROW

# A fake interpreter: logs its arguments to $log; `-c import pytest` exits $import_exit,
# `-m pytest` exits $pytest_exit, `-m venv --clear DIR` builds a fake venv in DIR.
fake_python() {
  local path="$1" log="$2" import_exit="$3" pytest_exit="$4"
  cat > "$path" <<PY
#!/bin/sh
echo "\$0 \$*" >> "$log"
case "\$1 \$2" in
  "-c import pytest") exit $import_exit ;;
  "-m pytest") exit $pytest_exit ;;
  "-m venv")
    dir="\$4"; mkdir -p "\$dir/bin"; : > "\$dir/pyvenv.cfg"
    cp "$path" "\$dir/bin/python"; printf '#!/bin/sh\necho "pip \$*" >> "$log"\n' > "\$dir/bin/pip"
    printf '#!/bin/sh\nexit 0\n' > "\$dir/bin/pytest"; chmod +x "\$dir/bin/pip" "\$dir/bin/pytest" "\$dir/bin/python"; exit 0 ;;
esac
exit 0
PY
  chmod +x "$path"
}

make_venv() { # dir import_exit pytest_exit
  local dir="$1"
  mkdir -p "$dir/bin"
  : > "$dir/bin/pytest"; chmod +x "$dir/bin/pytest"
  : > "$dir/pyvenv.cfg"
  fake_python "$dir/bin/python" "$dir.log" "$2" "$3"
}

run_suite() { # venv [extra PATH dir]
  SRC_ROOT="$root" FIXTURE="$root/fixtures/golden.hex" TEST_RESULTS="$work/results" \
    PACKBIN_PYTEST_VENV="$1" PATH="${2:+$2:}$PATH" \
    perl -e 'alarm 60; exec @ARGV' -- bash "$here/run-suite.sh" python </dev/null 2>&1
}

# 1. a venv that cannot import pytest
make_venv "$work/broken" 127 0
out="$(run_suite "$work/broken")"; code=$?
[ "$code" -ne 0 ] || bad "a broken venv passed"
case "$out" in
  *"$work/broken"*"is unusable"*"rm -rf "*"$work/broken"*) ;;
  *) bad "no message naming the broken venv and the rebuild command: $out" ;;
esac

# 2. a usable venv: pytest is really called with the tests path, and its success is the exit code
make_venv "$work/good" 0 0
out="$(run_suite "$work/good")"; code=$?
[ "$code" -eq 0 ] || bad "a usable venv failed (exit $code): $out"
grep -q -- "-m pytest -v --tb=short $root/python/tests" "$work/good.log" || bad "pytest was not run on the tests path: $(cat "$work/good.log")"

# 3. a failing pytest fails the run
make_venv "$work/red" 0 1
out="$(run_suite "$work/red")"; code=$?
[ "$code" -ne 0 ] || bad "a failing pytest passed"

# 4. a directory that is not a venv is not cleared
mkdir -p "$work/notvenv"; echo keep > "$work/notvenv/precious.txt"
mkdir -p "$work/fakebin"; fake_python "$work/fakebin/python" "$work/fakebin.log" 0 0
out="$(run_suite "$work/notvenv" "$work/fakebin")"; code=$?
[ "$code" -ne 0 ] || bad "a non-venv directory was accepted"
[ -f "$work/notvenv/precious.txt" ] || bad "a non-venv directory was cleared"
case "$out" in *"not a python venv"*) ;; *) bad "no message for a non-venv directory: $out" ;; esac

# 5. a missing venv is built with the pinned pytest and then used
out="$(run_suite "$work/fresh" "$work/fakebin")"; code=$?
[ "$code" -eq 0 ] || bad "a missing venv was not built (exit $code): $out"
pin="$(bash "$here/tool-pin.sh" pytest)"
grep -q "pip install --only-binary=:all: pytest==$pin" "$work/fakebin.log" || bad "pytest==$pin was not installed: $(cat "$work/fakebin.log")"

if [ "$fail" -eq 0 ]; then echo "run-suite.test.sh: all checks passed"; fi
exit "$fail"
