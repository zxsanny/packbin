#!/usr/bin/env bash
# The real frame drivers on malformed lines (AZ-3355): each of the 8 drivers must end with a non-zero exit and a message that
# names the line when a line has a bad hex digit, an odd-length hex token, a missing field or a number with other
# characters, and must answer `open-skip` / `verify-skip` with `skip`. The Go driver also refuses a bad direction, tag
# length or kind and a line over its scanner limit. ring-frame.test.sh runs the ring with stand-in drivers; this runs the
# drivers themselves, built and started as ring-frame.sh does (run_lang of ring-lib.sh).
#
# Environment: RING_FRAME_LANGS (default all eight), PACKBIN_RING_WORK (driver builds kept between runs), and the
# toolchain variables of language-pair.sh (PACKBIN_CXX_SYSROOT, CXX, PACKBIN_SWIFT_RING, RING_GO).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034 # read by run_lang, which is defined by the eval below
root="$(cd "$here/../.." && pwd)"
# shellcheck disable=SC2034 # drivers and swift_ring are read by run_lang, which is defined by the eval below
drivers="$here/drivers"
io="$(mktemp -d)"
trap 'rm -rf "$io"' EXIT
work="${PACKBIN_RING_WORK:-$io}"
mkdir -p "$work"
# shellcheck disable=SC2034 # read by run_lang, see above
swift_ring="${PACKBIN_SWIFT_RING:-/tmp/packbin-ring-swift}"
read -r -a langs <<< "${RING_FRAME_LANGS:-csharp typescript python rust cpp java go swift}"
limit_seconds="${RING_FRAME_DRIVER_LIMIT:-900}"

if [ ! -f "$here/ring-lib.sh" ]; then
  echo "ring-frame-drivers: $here/ring-lib.sh is missing" >&2
  exit 1
fi
definition="$(sed -n '/^run_lang() {$/,/^}$/p' "$here/ring-lib.sh")"
if [ -z "$definition" ]; then
  echo "ring-frame-drivers: ring-lib.sh has no run_lang to reuse" >&2
  exit 1
fi
eval "$definition"
export root drivers work swift_ring
export -f run_lang

key="1111111111111111111111111111111111111111111111111111111111111111"
id="00301005e8030000"
ad="000100301005e803000004"

# A good first line, so that the line number in the message is 2 and the output holds the answer to line 1.
files() {
  printf 'open-skip\nmac zz 1 6e6574 4 00\n' > "$io/bad-digit.in"
  printf 'open-skip\nmac %s 1 6e6574 4 00\n' "${key%?}" > "$io/odd-length.in"
  printf 'open-skip\nseal %s 1 1\n' "$key" > "$io/missing-field.in"
  printf 'open-skip\nmac %s x 6e6574 4 00\n' "$key" > "$io/bad-number.in"
  printf 'open-skip\nverify-skip\n' > "$io/skip.in"
  printf 'open-skip\nseal %s 1 x 4 %s 4 %s - 00\n' "$key" "$id" "$ad" > "$io/bad-direction.in"
  printf 'open-skip\nseal %s 1 1 x %s 4 %s - 00\n' "$key" "$id" "$ad" > "$io/bad-tag-length.in"
  printf 'open-skip\nseal %s 1 1 4 %s x %s - 00\n' "$key" "$id" "$ad" > "$io/bad-kind.in"
  { printf 'open-skip\nseal '; head -c 2097152 /dev/zero | tr '\0' 'a'; printf '\n'; } > "$io/long-line.in"
}

# run_limited <seconds> <lang> <args...>: run_lang with a time limit (run_lang is a function, so perl starts a bash that has it).
run_limited() {
  local seconds="$1"
  shift
  perl -e 'alarm shift; exec @ARGV' "$seconds" bash -c 'run_lang "$@"' _ "$@"
}

# check <lang> <case> <want: fail|skip>
check() {
  local lang="$1" name="$2" want="$3" rc=0 out="$io/$2.$1.out" err="$io/$2.$1.err"
  run_limited "$limit_seconds" "$lang" frame-batch "$io/$name.in" > "$out" 2> "$err" < /dev/null || rc=$?
  if [ "$want" = "skip" ]; then
    if [ "$rc" -ne 0 ] || [ "$(tr '\n' ' ' < "$out")" != "skip skip " ]; then
      echo "FAIL $lang $name: exit $rc, wanted 0 and two lines \"skip\""
      sed -n '1,3p' "$out" "$err" | cut -c1-160
      return 1
    fi
  elif [ "$rc" -eq 0 ]; then
    echo "FAIL $lang $name: exit 0, wanted non-zero"
    return 1
  elif ! grep -Eq 'line 2' "$err"; then
    echo "FAIL $lang $name: exit $rc but the message has no \"line 2\":"
    sed -n '1,3p' "$err" | cut -c1-160
    return 1
  elif [ "$(head -n 1 "$out")" != "skip" ]; then
    echo "FAIL $lang $name: the answer to line 1 is \"$(head -n 1 "$out")\", wanted \"skip\""
    return 1
  fi
  echo "PASS $lang $name"
}

lang_cases() {
  local lang="$1" bad=0 name
  for name in bad-digit odd-length missing-field bad-number; do
    check "$lang" "$name" fail || bad=1
  done
  check "$lang" skip skip || bad=1
  if [ "$lang" = go ]; then
    for name in bad-direction bad-tag-length bad-kind long-line; do
      check "$lang" "$name" fail || bad=1
    done
  fi
  return "$bad"
}

files
pids=()
for lang in "${langs[@]}"; do
  (lang_cases "$lang" > "$io/result.$lang" 2>&1) &
  pids+=("$!")
done
failed=""
i=0
for pid in "${pids[@]}"; do
  wait "$pid" || failed="$failed ${langs[$i]}"
  cat "$io/result.${langs[$i]}"
  i=$((i + 1))
done
echo "---"
if [ -n "$failed" ]; then
  echo "ring-frame-drivers: failed in:$failed"
  exit 1
fi
echo "ring-frame-drivers: all passed (${#langs[@]} languages)"
