#!/usr/bin/env bash
# Link checks and limits of the Rust embedded stage (AZ-2751). Sourced by target.sh; the functions read
# plain text (the output of `arm-none-eabi-nm`, one symbol per line), so checks.test.sh can feed them
# made-up images.

# Symbols that mean the heap is linked: the Rust allocator entry points and the C ones.
heap_hits() {
  awk '$NF ~ /^(__rust_alloc|__rust_dealloc|__rust_realloc|__rust_alloc_zeroed|__rg_alloc|__rg_dealloc|__rg_realloc|__rg_alloc_zeroed|__rust_no_alloc_shim_is_unstable|malloc|calloc|realloc|free|_malloc_r|_free_r|_realloc_r|_Znwj|_Znaj|__wrap_.*)$/ { print $NF }
       $NF ~ /alloc5alloc|alloc..alloc/ { print $NF }' "$1" | sort -u
}

# Symbols that mean a panic path is linked: the panic entry points, the failed bounds, unwrap, expect and
# slice-length checks, and the panic handler. Names are the raw (legacy mangled) ones, so a substring
# matches whatever the hash.
panic_hits() {
  awk '$NF ~ /(panicking|panic_fmt|panic_bounds_check|unwrap_failed|expect_failed|slice_index_fail|slice_end_index_len_fail|slice_start_index_len_fail|slice_index_order_fail|len_mismatch_fail|rust_begin_unwind|rust_panic|handle_alloc_error|unreachable_display|assert_failed)/ { print $NF }' "$1" | sort -u
}

# limit_of uses $limits_file, which target.sh (or the test) sets.
# shellcheck disable=SC2154
# limit_of <set> <column> prints the limit (a number, "-" for none, "missing" when the set has no line).
limit_of() {
  awk -v set="$1" -v col="$2" '$1 == set && $1 !~ /^#/ { print $col; found = 1 } END { if (!found) print "missing" }' "$limits_file"
}

# within <value> <limit>: success when the limit is "-" or the value fits.
within() {
  [ "$2" = "-" ] || [ "$2" = "missing" ] || [ "$1" -le "$2" ]
}
