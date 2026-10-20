#!/usr/bin/env bash
# Targets of the Rust embedded stage (AZ-2751), run inside packbin-embedded. Sourced by run.sh after
# cpp/embedded/lib.sh and cpp/embedded/arm.sh, whose startup code, linker script, stack meter, QEMU runner
# and report rows the Rust image reuses: the C++ and the Rust figures are measured by one method.
set -euo pipefail

rust_dir="$root/rust/embedded"
# PACKBIN_RUST_EMBEDDED_LIMITS names another limits file (the smoke test lowers a limit by one byte).
limits_file="${PACKBIN_RUST_EMBEDDED_LIMITS:-$rust_dir/limits.txt}"
rust_target=thumbv7em-none-eabihf
rust_arch=(-mthumb -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16)
# shellcheck source=checks.sh
source "$rust_dir/checks.sh"

# The static library cargo built for one set (run.sh libs).
rust_lib() {
  echo "$rust_dir/build/$1/$rust_target/release/libpackbin_probe.a"
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

target_rust_m4f() {
  local dir="$build/rust-m4f" set features lib meter flash0 flash stack raw hits sets=0
  rust_common_objects "$dir"
  rust_link "$dir" baseline.elf baseline.o
  qemu_run mps2-an386 "$dir/baseline.elf" "$dir/baseline.run.log" || fail "baseline image exit $?"
  # The meter reads its own unpainted guard as used; the baseline measures an empty call.
  meter=$(log_value PACK_STACK "$dir/baseline.run.log")
  flash0=$(arm-none-eabi-size "$dir/baseline.elf" | awk 'NR == 2 { print $1 + $2 }')
  while IFS='|' read -r set features; do
    sets=$((sets + 1))
    lib="$(rust_lib "$set")"
    if [ ! -f "$lib" ]; then
      fail "$set: no static library at $lib (run rust/embedded/run.sh libs)"
      continue
    fi
    rust_link "$dir" "$set.elf" main.o "$lib"
    arm-none-eabi-nm "$dir/$set.elf" > "$dir/$set.nm"
    hits="$(heap_hits "$dir/$set.nm" | tr '\n' ' ')"
    [ -z "$hits" ] || fail "$set: the heap is linked ($hits)"
    hits="$(panic_hits "$dir/$set.nm" | tr '\n' ' ')"
    [ -z "$hits" ] || fail "$set: a panic path is linked ($hits)"
    qemu_run mps2-an386 "$dir/$set.elf" "$dir/$set.run.log" || fail "$set: image exit $?"
    [ "$(log_value FAILURES "$dir/$set.run.log")" = 0 ] || fail "$set: a probe call failed"
    [ "$(log_value GOLDEN_OK "$dir/$set.run.log")" = 1 ] || fail "$set: the golden fixture did not decode on the device image"
    flash=$(( $(arm-none-eabi-size "$dir/$set.elf" | awk 'NR == 2 { print $1 + $2 }') - flash0 ))
    raw=$(for key in PACK_STACK UNPACK_STACK; do log_value "$key" "$dir/$set.run.log"; done | sort -n | tail -n 1)
    stack=$((raw - meter))
    echo "SIZE $set flash=$flash B (limit $(limit_of "$set" 2)) stack=$stack B (limit $(limit_of "$set" 3)) raw=$raw meter=$meter"
    note "$set flash ${flash} B of $(limit_of "$set" 2); stack ${stack} B of $(limit_of "$set" 3); golden decoded on the device image"
    within "$flash" "$(limit_of "$set" 2)" || fail "$set: flash ${flash} B over $(limit_of "$set" 2) B"
    within "$stack" "$(limit_of "$set" 3)" || fail "$set: stack ${stack} B over $(limit_of "$set" 3) B"
  done < <(rust_sets)
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
