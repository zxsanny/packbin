#!/usr/bin/env bash
# Self-test of checks.sh (AZ-2751): the heap and panic checks find what a made-up image holds and pass a clean
# one; the limits compare as written. No toolchain, image or network.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
limits_file="$tmp/limits.txt"
printf '# comment\nbase 8192 512\nwide - -\n' > "$limits_file"
# shellcheck source=checks.sh
# shellcheck source=checks.sh
source "$here/checks.sh"
bad=0
expect() { # description, expected, actual
  if [ "$2" != "$3" ]; then
    echo "FAIL: $1: expected '$2', got '$3'" >&2
    bad=$((bad + 1))
  fi
}

clean="$tmp/clean.nm"
printf '08000100 T main\n08000200 T pb_rs_route_pack\n08000300 T pb_rs_golden\n20000000 B packet\n08000400 T _ZN6packbin6nostd4pack17h0123456789abcdefE\n' > "$clean"
expect "clean image has no heap symbol" "" "$(heap_hits "$clean")"
expect "clean image has no panic symbol" "" "$(panic_hits "$clean")"

for sym in __rust_alloc __rust_dealloc __rust_realloc __rg_alloc malloc free _malloc_r _Znwj __wrap_malloc; do
  printf '08000100 T main\n08000500 T %s\n' "$sym" > "$tmp/heap.nm"
  expect "heap symbol $sym is found" "$sym" "$(heap_hits "$tmp/heap.nm")"
done
for sym in _ZN4core9panicking5panic17h0123456789abcdefE _ZN4core9panicking18panic_bounds_check17h0123456789abcdefE \
  _ZN4core6option13unwrap_failed17h0123456789abcdefE _ZN4core5slice5index26slice_end_index_len_fail17h0123456789abcdefE \
  _ZN4core5slice6copy_from_slice17len_mismatch_fail17h0123456789abcdefE rust_begin_unwind; do
  printf '08000100 T main\n08000500 T %s\n' "$sym" > "$tmp/panic.nm"
  expect "panic symbol $sym is found" "$sym" "$(panic_hits "$tmp/panic.nm")"
done
printf '08000500 T malloc\n08000600 T _ZN4core9panicking5panic17h01E\n' > "$tmp/both.nm"
expect "both checks run on one image: heap" "malloc" "$(heap_hits "$tmp/both.nm")"
expect "both checks run on one image: panic" "_ZN4core9panicking5panic17h01E" "$(panic_hits "$tmp/both.nm")"

expect "flash limit of base" "8192" "$(limit_of base 2)"
expect "stack limit of base" "512" "$(limit_of base 3)"
expect "no limit is a dash" "-" "$(limit_of wide 2)"
expect "an unknown set has no limit" "-" "$(limit_of other 2)"
within 8192 8192 || { echo "FAIL: 8192 fits 8192" >&2; bad=$((bad + 1)); }
within 8193 8192 && { echo "FAIL: 8193 fits 8192" >&2; bad=$((bad + 1)); }
within 99999999 - || { echo "FAIL: no limit rejects" >&2; bad=$((bad + 1)); }

[ "$bad" -eq 0 ] || { echo "checks.test.sh: $bad check(s) failed" >&2; exit 1; }
echo "checks.test.sh: all checks passed"
