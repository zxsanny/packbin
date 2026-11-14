#!/usr/bin/env bash
# TypeScript probe of AZ-4291 (see ../README.md). Node runs the source; nothing is built or written. One
# process per shape and depth, through ../case.sh, so a stack overflow or a hang is one line.
# Exit codes: 0 the probe ran (whatever it found), 1 no node on PATH.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v node >/dev/null; then
  printf 'typescript probe: no node on PATH\n' >&2
  exit 1
fi

# A probe that does not run at all must stop here, not show as six crashed cases.
node "$here/probe.ts" when 1 </dev/null >/dev/null

for shape in when group; do
  for depth in 1000 5000 50000; do
    bash "$here/../case.sh" typescript "$shape-$depth" 60 node "$here/probe.ts" "$shape" "$depth"
  done
done
