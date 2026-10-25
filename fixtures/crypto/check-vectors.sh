#!/usr/bin/env bash
# Re-derives every row of the primitive reference vectors with hashlib, hmac and the pure-Python ChaCha20.
# Usage: check-vectors.sh [vectors]
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
vectors="${1:-$here/vectors.txt}"

exec python3 -I "$root/scripts/crypto/check_vectors.py" "$vectors" < /dev/null
