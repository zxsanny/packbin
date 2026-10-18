#!/usr/bin/env bash
# Fails unless the contract holds the accept-chance table the reference computes. Usage: check-contract.sh [contract]
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
contract="${1:-$root/_docs/02_document/contracts/library/message-ecc.md}"

python3 -I "$root/scripts/ecc/accept_table.py" --check "$contract" < /dev/null && echo "PASS contract table matches the reference"
