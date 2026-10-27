#!/usr/bin/env bash
# The frame ring (AZ-3338): every language seals every row and every language opens what every language sealed, 8 writers
# × 8 readers = 64 pairs; then every language computes every MAC and every language verifies every other language's tag.
# The rows are the seal, mac, open and verify rows of fixtures/frame/ring-cases.txt (the last two are tampered input that every
# language must refuse alike); scripts/frame/ring_frame.py checks every result
# against the reference codec (scripts/frame/framefmt.py). Exit 0 only when no row is mismatched.
#
# A driver (.github/workflows/drivers) takes `frame-batch <file>`: one result line for each line of the file (seal, open,
# mac or verify), so a language costs one process start per phase, not one per row. run_lang is the one of ring-lib.sh
# (the runner language-pair.sh sources), read from it, so a driver is built and started exactly as there. The file is a
# path, not stdin: run_lang may build through docker, which would take stdin.
#
# Environment: RING_FRAME_RUN (a command that runs a driver in place of run_lang: `$RING_FRAME_RUN <lang> <args>`; the
# self-test of this script), PACKBIN_RING_WORK (the driver builds language-pair.sh kept), RING_FRAME_LANGS (the
# languages, default all eight), RING_FRAME_CASES (another cases file). The rest is language-pair.sh's:
# PACKBIN_CXX_SYSROOT, CXX, PACKBIN_SWIFT_RING, RING_GO.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
# shellcheck disable=SC2034 # drivers and swift_ring are read by run_lang, which is defined by the eval below
drivers="$here/drivers"
io="$(mktemp -d)"
trap 'rm -rf "$io"' EXIT
work="${PACKBIN_RING_WORK:-$io}"
mkdir -p "$work"
# shellcheck disable=SC2034 # read by run_lang, see above
swift_ring="${PACKBIN_SWIFT_RING:-/tmp/packbin-ring-swift}"
read -r -a langs <<< "${RING_FRAME_LANGS:-csharp typescript python rust cpp java go swift}"
checker="$root/scripts/frame/ring_frame.py"

if [ -n "${RING_FRAME_RUN:-}" ]; then
  run_lang() { "$RING_FRAME_RUN" "$@"; }
else
  if [ ! -f "$here/ring-lib.sh" ]; then
    echo "ring-frame: $here/ring-lib.sh is missing" >&2
    exit 1
  fi
  definition="$(sed -n '/^run_lang() {$/,/^}$/p' "$here/ring-lib.sh")"
  if [ -z "$definition" ]; then
    echo "ring-frame: ring-lib.sh has no run_lang to reuse" >&2
    exit 1
  fi
  eval "$definition"
fi

phase() {
  local name="$1" input="$2" lang failed="" pid
  local -a pids=()
  for lang in "${langs[@]}"; do
    (run_lang "$lang" frame-batch "$input" > "$io/$name.$lang.out" 2> "$io/$name.$lang.err" < /dev/null) &
    pids+=("$!")
  done
  local i=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed="$failed ${langs[$i]}"
      echo "ring-frame: ${langs[$i]} frame-batch ($name) failed:" >&2
      tail -n 15 "$io/$name.${langs[$i]}.err" >&2
    fi
    i=$((i + 1))
  done
  [ -z "$failed" ] || { echo "ring-frame: $name failed in:$failed" >&2; return 1; }
}

python3 -I "$checker" seal-in "$io"
phase seal "$io/seal.in"

python3 -I "$checker" open-in "$io" "${langs[@]}"
phase open "$io/open.in"

python3 -I "$checker" mac-in "$io"
phase mac "$io/mac.in"

python3 -I "$checker" verify-in "$io" "${langs[@]}"
phase verify "$io/verify.in"

python3 -I "$checker" check "$io" "${langs[@]}" -- "${langs[@]}"
