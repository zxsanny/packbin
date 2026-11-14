#!/usr/bin/env bash
# Python probe of AZ-4291 (see ../README.md). Python runs the package source; nothing is built or written.
# One process per shape and depth, through ../case.sh, so a stack overflow or a hang is one line.
# PACKBIN_PROBE_PYTHON names the interpreter; without it the first Python 3.10 or newer on PATH is used.
# Exit codes: 0 the probe ran (whatever it found), 1 no usable Python.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"

fail() {
  printf 'python probe: %s\n' "$1" >&2
  exit 1
}

# The package needs Python 3.10 or newer.
new_enough() {
  "$1" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' </dev/null
}

python="${PACKBIN_PROBE_PYTHON:-}"
if [[ -n "$python" ]]; then
  if ! command -v "$python" >/dev/null; then
    fail "PACKBIN_PROBE_PYTHON=$python is not a command"
  fi
  if ! new_enough "$python"; then
    fail "PACKBIN_PROBE_PYTHON=$python is older than Python 3.10"
  fi
else
  for candidate in python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" >/dev/null && new_enough "$candidate"; then
      python="$candidate"
      break
    fi
  done
  if [[ -z "$python" ]]; then
    fail "no Python 3.10 or newer on PATH (python3.14 to python3.10, python3); set PACKBIN_PROBE_PYTHON"
  fi
fi

export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$root/python/src"

# A probe that does not run at all must stop here, not show as six crashed cases.
"$python" "$here/probe.py" when 1 </dev/null >/dev/null

for shape in when group; do
  for depth in 1000 5000 50000; do
    bash "$here/../case.sh" python "$shape-$depth" 60 "$python" "$here/probe.py" "$shape" "$depth"
  done
done
