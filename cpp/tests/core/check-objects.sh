#!/bin/sh
# AC-4 (AZ-2655): the core objects allocate nothing, throw nothing and keep every table in
# read-only memory. Usage: check-objects.sh [--no-text | --no-text-binary | --no-ecc] FILE...
#  - no undefined symbol of an allocator, operator new/delete or the exception runtime;
#  - no writable data (size: the data and bss columns are 0), so the code tables are constants;
#  - the compact text tables are present in the objects that use them;
#  - with --no-text (objects built with -DPACKBIN_NO_TEXT, AZ-2656 CS-12) no object holds the
#    codec: no table and no encoder or decoder symbol.
#  - with --no-ecc (objects built with -DPACKBIN_NO_ECC, AZ-2688 EC-12) no object holds the
#    message error correction codec: no field table and no encode, syndrome or repair symbol.
set -eu
forbidden='^_*(malloc|calloc|realloc|free|posix_memalign|aligned_alloc|_Znwm|_Znam|_Znwj|_Znaj|_ZdlPv|_ZdaPv|_ZdlPvm|_ZdaPvm|_ZdlPvj|_ZdaPvj|__cxa_throw|__cxa_allocate_exception|__cxa_begin_catch|__cxa_end_catch|__cxa_rethrow|__gxx_personality_v0|_Unwind_Resume|__cxa_atexit)$'
no_text=0
binary=0
no_ecc=0
if [ "${1:-}" = "--no-text" ]; then
  no_text=1
  shift
elif [ "${1:-}" = "--no-ecc" ]; then
  no_ecc=1
  shift
elif [ "${1:-}" = "--no-text-binary" ]; then
  # A linked test binary: only the codec symbols are checked (it has writable data of its own).
  no_text=1
  binary=1
  shift
fi
ecc_codec='kGf|syndromes|locator|poly_at|generator|protect|repair'
codec='kTab|kLengths|kShared|kNumset|encode_field|decode_payload|decode_utf8|check_raw|write_compact'
failed=0
for obj in "$@"; do
  if [ "$binary" -eq 0 ] && nm "$obj" | awk '$(NF-1) == "U" { print $NF }' | grep -E "$forbidden"; then
    echo "object-check: $obj references an allocator or the exception runtime" >&2
    failed=1
  fi
  sizes=$(size "$obj" | awk 'NR == 2 { print $2, $3 }')
  if [ "$binary" -eq 0 ] && [ "$sizes" != "0 0" ]; then
    echo "object-check: $obj has writable data or bss (data bss: $sizes)" >&2
    failed=1
  fi
  if [ "$no_ecc" -eq 1 ]; then
    if nm "$obj" | grep -E "$ecc_codec"; then
      echo "object-check: $obj holds a message ECC table or symbol in a PACKBIN_NO_ECC build" >&2
      failed=1
    fi
    continue
  fi
  if [ "$no_text" -eq 1 ]; then
    if nm "$obj" | grep -E "$codec"; then
      echo "object-check: $obj holds a codec table or symbol in a PACKBIN_NO_TEXT build" >&2
      failed=1
    fi
    continue
  fi
  case "$obj" in
    */pack.o | */unpack.o)
      if ! nm "$obj" | grep -q 'kTab'; then
        echo "object-check: $obj does not hold the compact text tables" >&2
        failed=1
      fi
      ;;
  esac
done
if [ "$failed" -ne 0 ]; then
  exit 1
fi
if [ "$no_ecc" -eq 1 ]; then
  echo "object-check: $# objects built with PACKBIN_NO_ECC: no ECC table, no ECC symbol, no allocator, no writable data"
elif [ "$no_text" -eq 1 ]; then
  echo "object-check: $# objects built with PACKBIN_NO_TEXT: no codec table, no codec symbol, no allocator, no writable data"
else
  echo "object-check: $# objects: no allocator, no exception runtime, no writable data, tables in read-only memory"
fi
