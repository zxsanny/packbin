#!/usr/bin/env bash
# The message ECC ring (AZ-2689, EC-9): every language writes the protected position message and every language reads
# what every language wrote, intact and corrupted, 8 writers x 8 readers = 64 pairs. The rows are the position rows of
# fixtures/ecc/vectors.txt and fixtures/ecc/ring-cases.txt; scripts/ecc/ring_ecc.py checks every result against the
# reference codec (scripts/ecc/eccfmt.py). Exit 0 only when no row is mismatched.
#
# A driver (.github/workflows/drivers) takes `ecc-batch <file>`: one result line for each `protect <n> <hex>` or
# `repair <n> <t> <hex>` line of the file, so a language costs two process starts, not one for each row. run_lang is the
# one of ring-lib.sh (the runner language-pair.sh sources), read from it, so a driver is built and started exactly as
# there. The file is a path, not stdin: run_lang may build through docker, which would take stdin.
#
# Environment: RING_ECC_RUN (a command that runs a driver in place of run_lang: `$RING_ECC_RUN <lang> <args>`; the
# self-test of this script), PACKBIN_RING_WORK (the driver builds language-pair.sh kept), RING_ECC_LANGS (the
# languages, default all eight), RING_ECC_VECTORS and RING_ECC_CASES (other row files). The rest is language-pair.sh's:
# PACKBIN_CXX_SYSROOT, CXX, PACKBIN_SWIFT_RING, RING_GO.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
# shellcheck disable=SC2034 # drivers and swift_ring are read by run_lang, which is defined by the eval below
drivers="$here/drivers"
# io holds the files of this run. work holds the driver builds (run_lang's $work): the directory language-pair.sh built
# into and kept (PACKBIN_RING_WORK), so the C# and C++ drivers are not built twice in a run, else a directory of our own.
io="$(mktemp -d)"
trap 'rm -rf "$io"' EXIT
work="${PACKBIN_RING_WORK:-$io}"
mkdir -p "$work"
# shellcheck disable=SC2034 # read by run_lang, see above
swift_ring="${PACKBIN_SWIFT_RING:-/tmp/packbin-ring-swift}"
read -r -a langs <<< "${RING_ECC_LANGS:-csharp typescript python rust cpp java go swift}"
checker="$root/scripts/ecc/ring_ecc.py"

if [ -n "${RING_ECC_RUN:-}" ]; then
  run_lang() { "$RING_ECC_RUN" "$@"; }
else
  if [ ! -f "$here/ring-lib.sh" ]; then
    echo "ring-ecc: $here/ring-lib.sh is missing" >&2
    exit 1
  fi
  definition="$(sed -n '/^run_lang() {$/,/^}$/p' "$here/ring-lib.sh")"
  if [ -z "$definition" ]; then
    echo "ring-ecc: ring-lib.sh has no run_lang to reuse" >&2
    exit 1
  fi
  eval "$definition"
fi

# phase <name> <input file>: every language reads the file and writes <io>/<name>.<lang>.out, all at the same time (a
# language builds its own driver, so the builds share nothing). Returns 1, naming each language that failed.
phase() {
  local name="$1" input="$2" lang failed="" pid
  local -a pids=()
  for lang in "${langs[@]}"; do
    (run_lang "$lang" ecc-batch "$input" > "$io/$name.$lang.out" 2> "$io/$name.$lang.err" < /dev/null) &
    pids+=("$!")
  done
  local i=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed="$failed ${langs[$i]}"
      echo "ring-ecc: ${langs[$i]} ecc-batch ($name) failed:" >&2
      tail -n 15 "$io/$name.${langs[$i]}.err" >&2
    fi
    i=$((i + 1))
  done
  [ -z "$failed" ] || { echo "ring-ecc: $name failed in:$failed" >&2; return 1; }
}

python3 -I "$checker" protect-in "$io"
phase protect "$io/protect.in"
python3 -I "$checker" repair-in "$io" "${langs[@]}"
phase repair "$io/repair.in"
# Each reader's file is named repair.<reader>.out and holds the answers for the lines of repair.in, writer by writer.
python3 -I "$checker" check "$io" "${langs[@]}" -- "${langs[@]}"
