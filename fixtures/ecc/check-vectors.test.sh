#!/usr/bin/env bash
# Proves check-vectors.sh passes the committed file and fails on corrupted copies. Usage: check-vectors.test.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

expect() { # name want(0|1) file
  local rc=0
  "$here/check-vectors.sh" "$3" > "$tmp/out.txt" 2>&1 < /dev/null || rc=$?
  if [ "$rc" -ne "$2" ]; then echo "FAIL $1: exit $rc, wanted $2"; sed -n 1,5p "$tmp/out.txt"; fail=1; else echo "PASS $1"; fi
}

expect committed 0 "$here/vectors.txt"

# flip one hex digit of the first enc row's protected bytes
awk 'BEGIN{d=0} !d && $1=="enc" && $3>0 { c=substr($5,length($5),1); r=(c=="0")?"1":"0"; $5=substr($5,1,length($5)-1) r; d=1 } {print}' "$here/vectors.txt" > "$tmp/enc.txt"
expect enc-corrupt 1 "$tmp/enc.txt"

# say a refused row is accepted: change a kind
awk 'BEGIN{d=0} !d && $1=="bad" && $6=="uncorrectable" { $6="short"; d=1 } {print}' "$here/vectors.txt" > "$tmp/bad.txt"
expect bad-kind 1 "$tmp/bad.txt"

# drop the n = 32 rows
grep -v ' 32 ' "$here/vectors.txt" > "$tmp/cov.txt"
expect coverage 1 "$tmp/cov.txt"

# a duplicate id
{ cat "$here/vectors.txt"; grep -m1 '^enc ' "$here/vectors.txt"; } > "$tmp/dup.txt"
expect duplicate-id 1 "$tmp/dup.txt"

exit "$fail"
