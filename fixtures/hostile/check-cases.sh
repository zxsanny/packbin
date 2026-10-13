#!/usr/bin/env bash
# Checks the format of the hostile-case file and that README.md describes every id. A pack case also
# needs Scheme, Row, Run by and Not run by lines that together name each of the seven packages once.
# Usage: check-cases.sh [cases-file] [readme]
set -euo pipefail
set -f

here="$(cd "$(dirname "$0")" && pwd)"
cases="${1:-$here/cases.txt}"
readme="${2:-$here/README.md}"

terms="short_packet trailing_bytes bad_value too_many type_mismatch scheme_error"
packages=("C#" "C++" "Go" "Java" "Python" "Rust" "TypeScript")
errors=0
count=0
seen=" "
lineno=0

bad() {
  echo "$cases:$lineno: $1" >&2
  errors=$((errors + 1))
}

# A pack case's README section: the scheme, the row, and the Run by and Not run by lists, which
# together name each package exactly once. A pack case that expects bytes also writes the packet in
# its Packet line (spaces allowed) and its Expected line. A package name counts as a whole word: the
# text is split into words, so "Google" or "Got" in a reason is not the package Go.
check_pack_section() {
  local id="$1" expected="$2" hex="$3" section line run notrun pkg n packet
  section="$(awk -v head="## $id" '$0 == head { on = 1; next } /^## / { on = 0 } on' "$readme")"
  for line in Scheme Row; do
    grep -q "^- $line: " <<<"$section" || bad "pack case '$id': section has no '- $line:' line"
  done
  if [[ "$expected" == bytes ]]; then
    packet="$(grep -m1 '^- Packet ' <<<"$section" || true)"
    [[ "${packet// /}" == *"$hex"* ]] || bad "pack case '$id': Packet line does not hold the hex $hex"
    line="$(grep -m1 '^- Expected: ' <<<"$section" || true)"
    [[ "$line" == *"$hex"* ]] || bad "pack case '$id': Expected line does not hold the hex $hex"
  fi
  run="$(grep -m1 '^- Run by: ' <<<"$section" || true)"
  notrun="$(grep -m1 '^- Not run by: ' <<<"$section" || true)"
  if [[ -z "$run" ]]; then
    bad "pack case '$id': section has no '- Run by:' line"
  fi
  if [[ -z "$notrun" ]]; then
    bad "pack case '$id': section has no '- Not run by:' line"
  fi
  if [[ -z "$run" || -z "$notrun" ]]; then
    return
  fi
  for pkg in "${packages[@]}"; do
    n="$({ printf '%s\n%s\n' "$run" "$notrun" | tr -c 'A-Za-z0-9_#+\n' '\n' | grep -x -F -- "$pkg" || true; } | wc -l | tr -d ' ')"
    if [[ "$n" -ne 1 ]]; then
      bad "pack case '$id': package $pkg is named $n times in Run by and Not run by, expected once"
    fi
  done
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
  if [[ "$stage" != unpack && "$stage" != construct && "$stage" != limit && "$stage" != pack ]]; then
    bad "stage '$stage' must be unpack, construct, limit or pack"
  fi
  if [[ ! "$expected" =~ ^[a-z_]+(\|[a-z_]+)*$ ]]; then
    bad "expected '$expected' must be outcome terms joined by |"
  elif [[ "$stage" == pack ]]; then
    [[ "$expected" == bytes || "$expected" == pack_error ]] ||
      bad "a pack case expects bytes or pack_error, got '$expected'"
  else
    old_ifs="$IFS"
    IFS='|'
    for term in $expected; do
      if [[ "$term" == bytes || "$term" == pack_error ]]; then
        bad "outcome term '$term' belongs to the pack stage only"
      elif [[ " $terms " != *" $term "* ]]; then
        bad "unknown outcome term '$term'"
      fi
    done
    IFS="$old_ifs"
  fi
  if [[ "$stage" == construct ]]; then
    [[ "$hex" == "-" ]] || bad "a construct case has hex '-'"
  elif [[ "$stage" == pack && "$expected" == pack_error ]]; then
    [[ "$hex" == "-" ]] || bad "a pack_error case has hex '-'"
  elif [[ ! "$hex" =~ ^01([0-9a-f]{2})*$ ]]; then
    bad "hex '$hex' must be lowercase, even length, starting with 01"
  fi
  if ! grep -q "^## $id\$" "$readme"; then
    bad "id '$id' has no '## $id' section in $readme"
  elif [[ "$stage" == pack ]]; then
    check_pack_section "$id" "$expected" "$hex"
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
