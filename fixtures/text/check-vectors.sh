#!/usr/bin/env bash
# Re-derives every row of the compact text vectors file with the reference codec and checks the coverage
# the contract asks for (symbols, modes, row counts). Usage: check-vectors.sh [vectors] [tables]
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
vectors="${1:-$here/vectors.txt}"
tables="${2:-$here/tables.json}"

exec python3 "$root/scripts/text/check_vectors.py" "$vectors" "$tables" < /dev/null
