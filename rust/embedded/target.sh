#!/usr/bin/env bash
# Targets of the Rust embedded stage (AZ-2751), run inside packbin-embedded. Sourced by run.sh after
# cpp/embedded/lib.sh and cpp/embedded/arm.sh, whose startup code, linker script, stack meter, QEMU runner
# and report rows the Rust image reuses: the C++ and the Rust figures are measured by one method.
set -euo pipefail

rust_dir="$root/rust/embedded"
# PACKBIN_RUST_EMBEDDED_LIMITS_M33F names another limits file (the smoke test lowers a pin by one byte).
limits_file="${PACKBIN_RUST_EMBEDDED_LIMITS_M33F:-$rust_dir/limits-m33f.txt}"
# The one target of the stage: the Cortex-M33F of the nRF54L15 on QEMU mps2-an505 (Secure state: code at 0x10000000,
# RAM at 0x38000000), held to the chip-scale ceilings of lib.sh (m33f_*) and to the pins of limits-m33f.txt. The link
# script is the one the C++ M33F row uses, so both check the same 128 KiB window.
rust_target=thumbv8m.main-none-eabihf
rust_build=build
rust_arch=(-mthumb -mcpu=cortex-m33 -mfloat-abi=hard -mfpu=fpv5-sp-d16)
rust_machine=mps2-an505
rust_flash_ceiling="$m33f_flash_budget"
rust_stack_ceiling="$m33f_stack_budget"
rust_ram_end="$m33f_ram_end"
arm_link_common=(-nostartfiles -T "$here/arm/mps2-an505.ld" -Wl,--gc-sections -Wl,--cref)
# shellcheck source=checks.sh
source "$rust_dir/checks.sh"

# The static library cargo built for one set (run.sh libs).
rust_lib() {
  echo "$rust_dir/$rust_build/$1/$rust_target/release/libpackbin_probe.a"
}

# The feature sets of feature-sets.txt, one "name|features" line each, comments and blanks left out.
rust_sets() {
  awk '!/^#/ && NF' "$rust_dir/feature-sets.txt"
}

# Startup, wrappers and the image without packbin (the stack meter's own overhead), in "$1".
rust_common_objects() {
  local dir="$1" golden
  golden="$(tr -d '[:space:]' < "$root/fixtures/golden.hex")"
  rm -rf "$dir"
  mkdir -p "$dir"
  : > "$dir/compile.log"
  arm_cc "$dir" "$here/arm/startup.c" startup.o "${rust_arch[@]}"
  arm_cc "$dir" "$here/arm/wrap.c" wrap.o "${rust_arch[@]}"
  arm_cxx "$dir" "$rust_dir/main.cpp" main.o "${rust_arch[@]}" "-DGOLDEN_HEX=\"$golden\""
  arm_cxx "$dir" "$rust_dir/main.cpp" baseline.o "${rust_arch[@]}" -DRUST_BASELINE "-DGOLDEN_HEX=\"$golden\""
  [ "$(count_warnings "$dir/compile.log")" -eq 0 ] || fail "compile warnings in the Rust image"
}

# Links one image: the common objects, the main object `$3` and, when `$4` is a library, that library.
rust_link() {
  local dir="$1" elf="$2" main="$3" lib="${4:-}"
  local extra=()
  [ -z "$lib" ] || extra=("$lib")
  # --no-warn-execstack: newlib's init.o has no .note.GNU-stack section and ld 2.41 warns about it as soon as a
  # Rust object (which has one) is linked; a Cortex-M image has no executable-stack notion and arm_link fails on
  # any warning.
  arm_link "$dir" "$elf" "${rust_arch[@]}" "${arm_link_common[@]}" -Wl,--no-warn-execstack \
    --specs=nano.specs --specs=nosys.specs \
    "${heap_wraps[@]}" "$dir/startup.o" "$dir/wrap.o" "$dir/$main" "${extra[@]}"
}

# The sets, checks and method of one row: every set linked, run, checked and measured for the target above.
target_rust_m33f() {
  rust_row "$build/rust-m33f"
}

# One row: every set of feature-sets.txt linked, run, checked and measured.
rust_row() {
  local dir="$1" set features lib meter flash0 ram0 ram flash stack raw hits sets=0
  rust_common_objects "$dir"
  rust_link "$dir" baseline.elf baseline.o
  check_ram_end "$dir/baseline.elf" "$rust_ram_end"
  qemu_run "$rust_machine" "$dir/baseline.elf" "$dir/baseline.run.log" || fail "baseline image exit $?"
  # The meter reads its own unpainted guard as used; the baseline measures an empty call.
  meter=$(log_value PACK_STACK "$dir/baseline.run.log")
  flash0=$(arm-none-eabi-size "$dir/baseline.elf" | awk 'NR == 2 { print $1 + $2 }')
  ram0=$(arm-none-eabi-size "$dir/baseline.elf" | awk 'NR == 2 { print $2 + $3 }')
  # The list is read on fd 3 so that QEMU and the toolchain cannot swallow the sets that follow.
  while IFS='|' read -r -u 3 set features; do
    sets=$((sets + 1))
    lib="$(rust_lib "$set")"
    if [ ! -f "$lib" ]; then
      fail "$set: no static library at $lib (run rust/embedded/run.sh libs)"
      continue
    fi
    if [ "$(limit_of "$set" 2)" = missing ]; then
      fail "$set: no line in the limits file (write '$set - -' for no limit)"
      continue
    fi
    rust_link "$dir" "$set.elf" main.o "$lib"
    check_ram_end "$dir/$set.elf" "$rust_ram_end"
    arm-none-eabi-nm "$dir/$set.elf" > "$dir/$set.nm"
    hits="$(heap_hits "$dir/$set.nm" | tr '\n' ' ')"
    [ -z "$hits" ] || fail "$set: the heap is linked ($hits)"
    hits="$(panic_hits "$dir/$set.nm" | tr '\n' ' ')"
    [ -z "$hits" ] || fail "$set: a panic path is linked ($hits)"
    qemu_run "$rust_machine" "$dir/$set.elf" "$dir/$set.run.log" || fail "$set: image exit $?"
    [ "$(log_value FAILURES "$dir/$set.run.log")" = 0 ] || fail "$set: a probe call failed"
    [ "$(log_value GOLDEN_OK "$dir/$set.run.log")" = 1 ] || fail "$set: the golden fixture did not decode on the device image"
    flash=$(( $(arm-none-eabi-size "$dir/$set.elf" | awk 'NR == 2 { print $1 + $2 }') - flash0 ))
    # The C++ stage requires the core to add no .data or .bss (no static mutable state); so does this one.
    ram=$(( $(arm-none-eabi-size "$dir/$set.elf" | awk 'NR == 2 { print $2 + $3 }') - ram0 ))
    [ "$ram" -eq 0 ] || fail "$set: the library adds ${ram} B of .data and .bss"
    raw=$(for key in PACK_STACK UNPACK_STACK EXTRA_STACK; do log_value "$key" "$dir/$set.run.log"; done | sort -n | tail -n 1)
    stack=$((raw - meter))
    echo "SIZE $set ram=$ram B flash=$flash B (limit $(limit_of "$set" 2)) stack=$stack B (limit $(limit_of "$set" 3)) raw=$raw meter=$meter"
    note "$set flash ${flash} B of $(limit_of "$set" 2); stack ${stack} B of $(limit_of "$set" 3); golden decoded on the device image"
    within "$flash" "$(limit_of "$set" 2)" || fail "$set: flash ${flash} B over $(limit_of "$set" 2) B"
    within "$stack" "$(limit_of "$set" 3)" || fail "$set: stack ${stack} B over $(limit_of "$set" 3) B"
    within "$flash" "$rust_flash_ceiling" || fail "$set: flash ${flash} B over the ceiling of ${rust_flash_ceiling} B"
    within "$stack" "$rust_stack_ceiling" || fail "$set: stack ${stack} B over the ceiling of ${rust_stack_ceiling} B"
  done 3< <(rust_sets)
  [ "$sets" -gt 0 ] || fail "feature-sets.txt lists no set"
}

# The link checks must fail on a real defect: images built from a probe that indexes a table by its input
# (a panic path) and one that boxes a value (the heap) must be caught.
target_rust_mutants() {
  local dir="$build/rust-mutants" kind lib hits
  rust_common_objects "$dir"
  for kind in panic heap; do
    lib="$(rust_lib "mutant-$kind")"
    if [ ! -f "$lib" ]; then
      fail "no static library for the seeded $kind defect at $lib (run rust/embedded/run.sh libs)"
      continue
    fi
    rust_link "$dir" "mutant-$kind.elf" main.o "$lib"
    arm-none-eabi-nm "$dir/mutant-$kind.elf" > "$dir/mutant-$kind.nm"
    if [ "$kind" = panic ]; then
      hits="$(panic_hits "$dir/mutant-$kind.nm" | tr '\n' ' ')"
    else
      hits="$(heap_hits "$dir/mutant-$kind.nm" | tr '\n' ' ')"
    fi
    if [ -z "$hits" ]; then
      fail "the $kind check found nothing in the image with the seeded $kind defect"
    else
      note "seeded $kind defect caught: $hits"
    fi
  done
}
