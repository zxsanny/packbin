#!/usr/bin/env bash
# The real frame drivers on malformed lines (AZ-3355): each of the 8 drivers must end with a non-zero exit and a message that
# names the line when a line has a bad hex digit, an odd-length hex token, a missing field or a number with other
# characters, and must answer `open-skip` / `verify-skip` with `skip`. The Go driver also refuses a bad direction, tag
# length or kind and a line over its scanner limit. The number ranges (AZ-3356, fixtures/frame/README.md): a number one
# above its field's top (dir, tag_len, kind, n 255; epoch 4294967295; clear_len, out_len 65535) or with a sign is a
# malformed line in every driver, and a number at the top goes to the package unchanged (direction 255 and epoch
# 4294967295 are its BadValue, an out_len of 65535 seals E1). A key that is not 32 bytes and a msg_id that is not 8 bytes
# (0, 7, 9 bytes; AZ-3378) is `BadValue` in every driver, a well-formed line: Rust and C++ cannot hand such a value to their
# package and answer it themselves (fixtures/frame/README.md). ring-frame.test.sh runs the ring with stand-in drivers;
# this runs the drivers themselves, built and started as ring-frame.sh does (run_lang of ring-lib.sh).
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
plain="0102030405060708090a0b0c"
body="53e9dc75fb459d775e6205661cdf37ff" # row E1 of ring-cases.txt

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
  # One above the top of each range, and a sign (AZ-3356); then the top itself.
  printf 'open-skip\nseal %s 1 256 4 %s 4 %s - %s 123 300\n' "$key" "$id" "$ad" "$plain" > "$io/dir-256.in"
  printf 'open-skip\nseal %s 1 -1 4 %s 4 %s - %s 123 300\n' "$key" "$id" "$ad" "$plain" > "$io/dir-minus-1.in"
  printf 'open-skip\nseal %s 1 1 256 %s 4 %s - %s 123 300\n' "$key" "$id" "$ad" "$plain" > "$io/tag-length-256.in"
  printf 'open-skip\nopen %s 1 1 4 %s 256 %s 0 %s 123 300\n' "$key" "$id" "$ad" "$body" > "$io/kind-256.in"
  printf 'open-skip\nopen %s 1 1 4 %s 4 %s 65536 %s 123 300\n' "$key" "$id" "$ad" "$body" > "$io/clear-length-65536.in"
  printf 'open-skip\nseal %s 1 1 4 %s 4 %s - %s 123 65536\n' "$key" "$id" "$ad" "$plain" > "$io/out-length-65536.in"
  printf 'open-skip\nmac %s 4294967296 6e6574 4 e803\n' "$key" > "$io/epoch-4294967296.in"
  printf 'open-skip\nverify %s 7 6e6574 256 e803 56db9bec\n' "$key" > "$io/n-256.in"
  printf 'open-skip\nseal %s 1 255 4 %s 4 %s - %s 123 300\n' "$key" "$id" "$ad" "$plain" > "$io/dir-255.in"
  printf 'open-skip\nmac %s 4294967295 6e6574 4 e803\n' "$key" > "$io/epoch-4294967295.in"
  printf 'open-skip\nseal %s 1 1 4 %s 4 %s - %s 123 65535\n' "$key" "$id" "$ad" "$plain" > "$io/out-length-65535.in"
  # A key and a msg_id of the wrong length (AZ-3378): 31, 33 and 0 bytes ("-"), 7, 9 and 0 bytes.
  local size wrong
  for size in 31 33 0; do
    case "$size" in 31) wrong="${key%??}" ;; 33) wrong="${key}aa" ;; *) wrong="-" ;; esac
    printf 'open-skip\nseal %s 1 1 4 %s 4 %s - %s 123 300\n' "$wrong" "$id" "$ad" "$plain" > "$io/seal-key-$size.in"
    printf 'open-skip\nopen %s 1 1 4 %s 4 %s 0 %s 123 300\n' "$wrong" "$id" "$ad" "$body" > "$io/open-key-$size.in"
    printf 'open-skip\nmac %s 7 6e6574 4 e803\n' "$wrong" > "$io/mac-key-$size.in"
    printf 'open-skip\nverify %s 7 6e6574 4 e803 56db9bec\n' "$wrong" > "$io/verify-key-$size.in"
  done
  for size in 7 9 0; do
    case "$size" in 7) wrong="${id%??}" ;; 9) wrong="${id}aa" ;; *) wrong="-" ;; esac
    printf 'open-skip\nseal %s 1 1 4 %s 4 %s - %s 123 300\n' "$key" "$wrong" "$ad" "$plain" > "$io/seal-id-$size.in"
    printf 'open-skip\nopen %s 1 1 4 %s 4 %s 0 %s 123 300\n' "$key" "$wrong" "$ad" "$body" > "$io/open-id-$size.in"
  done
}

# run_limited <seconds> <lang> <args...>: run_lang with a time limit (run_lang is a function, so perl starts a bash that has it).
run_limited() {
  local seconds="$1"
  shift
  perl -e 'alarm shift; exec @ARGV' "$seconds" bash -c 'run_lang "$@"' _ "$@"
}

# check <lang> <case> <want: fail|skip|=<answer to line 2>>
check() {
  local lang="$1" name="$2" want="$3" rc=0 out="$io/$2.$1.out" err="$io/$2.$1.err" answer
  run_limited "$limit_seconds" "$lang" frame-batch "$io/$name.in" > "$out" 2> "$err" < /dev/null || rc=$?
  if [ "$want" = "skip" ] || [ "${want#=}" != "$want" ]; then
    answer="${want#=}"
    if [ "$rc" -ne 0 ] || [ "$(tr '\n' ' ' < "$out")" != "skip $answer " ]; then
      echo "FAIL $lang $name: exit $rc, wanted 0 and the lines \"skip\" and \"$answer\""
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
  for name in dir-256 dir-minus-1 tag-length-256 kind-256 clear-length-65536 out-length-65536 epoch-4294967296 n-256; do
    check "$lang" "$name" fail || bad=1
  done
  check "$lang" dir-255 =BadValue || bad=1
  check "$lang" epoch-4294967295 =BadValue || bad=1
  check "$lang" out-length-65535 "=$body" || bad=1
  for name in seal-key-31 seal-key-33 seal-key-0 open-key-31 open-key-33 open-key-0 mac-key-31 mac-key-33 mac-key-0 \
    verify-key-31 verify-key-33 verify-key-0 seal-id-7 seal-id-9 seal-id-0 open-id-7 open-id-9 open-id-0; do
    check "$lang" "$name" =BadValue || bad=1
  done
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
echo "ring-frame-drivers: all passed (${#langs[@]} languages, $(cat "$io"/result.* | grep -c '^PASS ') checks)"
