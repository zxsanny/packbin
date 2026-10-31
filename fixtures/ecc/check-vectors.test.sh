#!/usr/bin/env bash
# Proves check-vectors.sh passes the committed file and fails on corrupted copies. Usage: check-vectors.test.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

expect() { # name want(0|1) vectors-file [percent-file]
  local rc=0
  PACKBIN_ECC_QUICK=1 "$here/check-vectors.sh" "$3" "${4:-$here/percent-vectors.txt}" > "$tmp/out.txt" 2>&1 < /dev/null || rc=$?
  if [ "$rc" -ne "$2" ]; then echo "FAIL $1: exit $rc, wanted $2"; sed -n 1,5p "$tmp/out.txt"; fail=1; else echo "PASS $1"; fi
}

# the committed files, with the sweep of every percentage against every length (about 15 s)
rc=0
"$here/check-vectors.sh" > "$tmp/out.txt" 2>&1 < /dev/null || rc=$?
if [ "$rc" -ne 0 ]; then echo "FAIL committed-full: exit $rc"; sed -n 1,5p "$tmp/out.txt"; fail=1; else echo "PASS committed-full"; fi
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

# a count of a percentage row that is one too high
awk 'BEGIN{d=0} !d && $1=="pct" && $5>0 { $5=$5+1; d=1 } {print}' "$here/percent-vectors.txt" > "$tmp/pct.txt"
expect pct-count 1 "$here/vectors.txt" "$tmp/pct.txt"

# a percentage row whose protected bytes lose a digit
awk 'BEGIN{d=0} !d && $1=="encp" && $3>0 { c=substr($5,length($5),1); r=(c=="0")?"1":"0"; $5=substr($5,1,length($5)-1) r; d=1 } {print}' "$here/percent-vectors.txt" > "$tmp/encp.txt"
expect encp-corrupt 1 "$here/vectors.txt" "$tmp/encp.txt"

# a sent length that has a clear length, said to have none
awk 'BEGIN{d=0} !d && $1=="inv" && $3>0 && $5!="none" { $5="none"; d=1 } {print}' "$here/percent-vectors.txt" > "$tmp/inv.txt"
expect inv-none 1 "$here/vectors.txt" "$tmp/inv.txt"

# a refusal under a percentage said to be another kind
awk 'BEGIN{d=0} !d && $1=="badp" && $6=="uncorrectable" { $6="too_long"; d=1 } {print}' "$here/percent-vectors.txt" > "$tmp/badp.txt"
expect badp-kind 1 "$here/vectors.txt" "$tmp/badp.txt"

# no percentage rows at all
grep -v -E '^(pct|encp) ' "$here/percent-vectors.txt" > "$tmp/nopct.txt"
expect no-percent-rows 1 "$here/vectors.txt" "$tmp/nopct.txt"

exit "$fail"
