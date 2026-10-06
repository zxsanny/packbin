#!/usr/bin/env bash
# Checks the format of the hostile-case file and that README.md describes every id.
# Usage: check-cases.sh [cases-file] [readme]
set -euo pipefail
set -f

here="$(cd "$(dirname "$0")" && pwd)"
cases="${1:-$here/cases.txt}"
readme="${2:-$here/README.md}"

terms="short_packet trailing_bytes bad_value too_many type_mismatch scheme_error"
errors=0
count=0
seen=" "
lineno=0

bad() {
  echo "$cases:$lineno: $1" >&2
  errors=$((errors + 1))
}

while IFS= read -r line || [[ -n "$line" ]]; do
  lineno=$((lineno + 1))
  case "$line" in
    '' | '#'*) continue ;;
  esac
  # shellcheck disable=SC2086
  set -- $line
  if [[ $# -ne 4 ]]; then
    bad "expected 4 fields (id stage expected hex), got $#"
    continue
  fi
  id="$1"
  stage="$2"
  expected="$3"
  hex="$4"
  count=$((count + 1))
  if [[ ! "$id" =~ ^[a-z0-9_]+$ ]]; then
    bad "id '$id' must match [a-z0-9_]+"
  elif [[ "$seen" == *" $id "* ]]; then
    bad "duplicate id '$id'"
  else
    seen="$seen$id "
  fi
  if [[ "$stage" != unpack && "$stage" != construct && "$stage" != limit ]]; then
    bad "stage '$stage' must be unpack, construct or limit"
  fi
  if [[ ! "$expected" =~ ^[a-z_]+(\|[a-z_]+)*$ ]]; then
    bad "expected '$expected' must be outcome terms joined by |"
  else
    old_ifs="$IFS"
    IFS='|'
    for term in $expected; do
      if [[ " $terms " != *" $term "* ]]; then
        bad "unknown outcome term '$term'"
      fi
    done
    IFS="$old_ifs"
  fi
  if [[ "$stage" == construct ]]; then
    [[ "$hex" == "-" ]] || bad "a construct case has hex '-'"
  elif [[ ! "$hex" =~ ^01([0-9a-f]{2})*$ ]]; then
    bad "hex '$hex' must be lowercase, even length, starting with 01"
  fi
  if ! grep -q "^## $id\$" "$readme"; then
    bad "id '$id' has no '## $id' section in $readme"
  fi
done <"$cases"

if [[ "$count" -eq 0 ]]; then
  lineno=0
  bad "no cases found"
fi
if [[ "$errors" -ne 0 ]]; then
  exit 1
fi
echo "hostile cases ok: $count"
