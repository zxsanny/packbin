#!/usr/bin/env bash
# Checks fixtures/frame/vectors.txt (or the file given): the reference re-derives every row and the coverage list is
# complete, and a second implementation written from the contract alone recomputes E1 to E5 and three more rows.
set -euo pipefail
cd "$(dirname "$0")/../.."
file="${1:-fixtures/frame/vectors.txt}"
python3 -I scripts/frame/check_vectors.py "$file"
python3 -I scripts/frame/independent_check.py "$file"
