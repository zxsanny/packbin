#!/usr/bin/env bash
# Proves check-vectors.sh passes the committed file and fails, naming the row, on copies with one expected byte
# changed in the rows of each primitive. Usage: check-vectors.test.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

expect() { # name want(0|1) file [row id that the output must name]
  local rc=0
  "$here/check-vectors.sh" "$3" > "$tmp/out.txt" 2>&1 < /dev/null || rc=$?
  if [ "$rc" -ne "$2" ]; then echo "FAIL $1: exit $rc, wanted $2"; sed -n 1,5p "$tmp/out.txt"; fail=1
  elif [ -n "${4:-}" ] && ! grep -q "FAIL .*: $4: " "$tmp/out.txt"; then echo "FAIL $1: output does not name row $4"; sed -n 1,5p "$tmp/out.txt"; fail=1
  else echo "PASS $1"; fi
}

# flip the last hex digit of one field (name=) in the first row of a primitive
corrupt() { # primitive field out
  awk -v p="$1" -v f="$2" 'BEGIN{d=0} !d && $1==p { for(i=3;i<=NF;i++) if (index($i,f "=")==1) { c=substr($i,length($i),1); r=(c=="0")?"1":"0"; $i=substr($i,1,length($i)-1) r; d=1; break } } {print}' "$here/vectors.txt" > "$3"
  if cmp -s "$here/vectors.txt" "$3"; then echo "FAIL corrupt $1: no row changed"; fail=1; fi
}

expect committed 0 "$here/vectors.txt"

corrupt sha256 digest "$tmp/sha256.txt"
expect sha256-corrupt 1 "$tmp/sha256.txt" "sha256 nist:empty"
corrupt hmac256 mac "$tmp/hmac.txt"
expect hmac-corrupt 1 "$tmp/hmac.txt" "hmac256 rfc4231:4.2"
corrupt hkdf256 okm "$tmp/hkdf.txt"
expect hkdf-corrupt 1 "$tmp/hkdf.txt" "hkdf256 rfc5869:a.1"
corrupt chacha-block block "$tmp/chacha-block.txt"
expect chacha-block-corrupt 1 "$tmp/chacha-block.txt" "chacha-block rfc8439:2.3.2"
corrupt chacha-xor cipher "$tmp/chacha-xor.txt"
expect chacha-xor-corrupt 1 "$tmp/chacha-xor.txt" "chacha-xor rfc8439:2.4.2"

# a non-derived row without a source section
sed 's/^sha256 fips180-4:b.1 /sha256 unknown /' "$here/vectors.txt" > "$tmp/source.txt"
expect no-source 1 "$tmp/source.txt" "sha256 unknown"

exit "$fail"
