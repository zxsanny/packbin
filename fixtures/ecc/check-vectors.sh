#!/usr/bin/env bash
# Re-derives every row of the message ECC vectors files with the reference codec and checks the coverage
# the contract asks for. Usage: check-vectors.sh [vectors [percent-vectors]]
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
vectors="${1:-$here/vectors.txt}"
percent="${2:-$here/percent-vectors.txt}"

python3 -I "$root/scripts/ecc/check_vectors.py" "$vectors" < /dev/null
exec python3 -I "$root/scripts/ecc/check_vectors.py" --percent "$percent" < /dev/null
