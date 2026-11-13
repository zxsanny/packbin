#!/usr/bin/env bash
# Cortex-M, big-endian and AVR targets (packbin-embedded image). Sourced by run.sh after lib.sh.
set -euo pipefail

arm_link_common=(-nostartfiles -T "$here/arm/mps2.ld" -Wl,--gc-sections -Wl,--cref)
heap_wraps=(-Wl,--wrap=malloc,--wrap=calloc,--wrap=realloc,--wrap=_Znwj,--wrap=_Znaj)
# Longest one QEMU image may run, in seconds; `timeout` kills a hung image (exit 124), which fails the target.
qemu_timeout_s=300

# Compiles one C++ source with the AC-1 flags; output (warnings included) goes to the log.
arm_cxx() {
  local dir="$1" src="$2" obj="$3" status=0
  shift 3
  arm-none-eabi-g++ "${core_flags[@]}" "$@" -ffunction-sections -fdata-sections \
    -I"$cpp/include" -I"$cpp/tests/core" -I"$here/common" -I"$here/arm" \
    -c "$src" -o "$dir/$obj" 2>&1 | tee -a "$dir/compile.log" || status=$?
  if [ "$status" -ne 0 ]; then
    fail "compile $(basename "$src") exit $status"
    return 1
  fi
}

arm_cc() {
  local dir="$1" src="$2" obj="$3" status=0
  shift 3
  arm-none-eabi-gcc "${c_flags[@]}" "$@" -ffunction-sections -fdata-sections \
    -I"$here/arm" -c "$src" -o "$dir/$obj" 2>&1 | tee -a "$dir/compile.log" || status=$?
  if [ "$status" -ne 0 ]; then
    fail "compile $(basename "$src") exit $status"
    return 1
  fi
}

# Core objects, the all-kinds scheme and the AC-2 firmware objects.
arm_firmware_objects() {
  local dir="$1"
  shift
  rm -rf "$dir"
  mkdir -p "$dir"
  : > "$dir/compile.log"
  local src
  for src in "${core_srcs[@]}"; do
    arm_cxx "$dir" "$cpp/$src" "core-$(basename "${src%.cpp}").o" "$@"
  done
  arm_cxx "$dir" "$here/common/all_kinds.cpp" all_kinds.o "$@"
  arm_cxx "$dir" "$here/common/all_kinds_rounds.cpp" all_kinds_rounds.o "$@"
  arm_cxx "$dir" "$here/arm/ac2_main.cpp" ac2_main.o "$@"
  arm_cc "$dir" "$here/arm/startup.c" startup.o "$@"
  arm_cc "$dir" "$here/arm/wrap.c" wrap.o "$@"
  local warnings
  warnings=$(count_warnings "$dir/compile.log")
  echo "compile warnings: $warnings"
  [ "$warnings" -eq 0 ] || fail "$warnings compile warning(s)"
}

arm_link() {
  local dir="$1" elf="$2" status=0
  shift 2
  arm-none-eabi-g++ "$@" -Wl,-Map="$dir/${elf%.elf}.map" -o "$dir/$elf" 2>&1 \
    | tee "$dir/${elf%.elf}.link.log" || status=$?
  if [ "$status" -ne 0 ]; then
    fail "link $elf exit $status"
    return 1
  fi
  local warnings
  warnings=$(count_warnings "$dir/${elf%.elf}.link.log")
  [ "$warnings" -eq 0 ] || fail "$warnings link warning(s) in $elf"
  arm-none-eabi-size "$dir/$elf"
}

arm_link_ac2() {
  local dir="$1"
  shift
  arm_link "$dir" ac2.elf "$@" "${arm_link_common[@]}" --specs=nano.specs --specs=nosys.specs \
    "${heap_wraps[@]}" "$dir"/core-*.o "$dir/all_kinds.o" "$dir/all_kinds_rounds.o" \
    "$dir/ac2_main.o" "$dir/startup.o" "$dir/wrap.o"
}

# AC-2 / AC-6 link-time checks on one image: exception, heap and OS random references.
image_checks() {
  local dir="$1" stem="$2"
  local map="$dir/$stem.map" elf="$dir/$stem.elf" syms="$dir/$stem.syms"
  arm-none-eabi-nm "$elf" > "$syms"
  local throw alloc heap osrnd urandom
  throw=$(count_fixed "__cxa_throw" "$map")
  alloc=$(count_fixed "__cxa_allocate_exception" "$map")
  heap=$(awk '$NF ~ /^(malloc|calloc|realloc|_Znwj|_Znaj|_malloc_r|__wrap_.*)$/ { n++ } END { print n + 0 }' "$syms")
  osrnd=$(awk '$NF ~ /(getrandom|arc4random)/ { n++ } END { print n + 0 }' "$syms")
  urandom=$(count_fixed "/dev/urandom" "$elf")
  echo "$stem: __cxa_throw=$throw __cxa_allocate_exception=$alloc heap_symbols=$heap os_rng_symbols=$osrnd dev_urandom=$urandom"
  [ "$((throw + alloc))" -eq 0 ] || fail "$stem references exceptions ($throw throw $alloc allocate)"
  [ "$osrnd" -eq 0 ] && [ "$urandom" -eq 0 ] || fail "$stem references OS random"
  if [ "$stem" = ac2 ] || [ "$stem" = frame ]; then
    [ "$heap" -eq 0 ] || fail "$stem references the heap ($heap symbol(s))"
  fi
  printf '%s %s %s %s\n' "$throw" "$alloc" "$heap" "$((osrnd + urandom))" > "$dir/$stem.refs"
}

# The stack top of a linked image is the end of its RAM region: the M33F rows hold it to the 128 KiB window (AZ-3469).
check_ram_end() {
  local elf="$1" expected="$2" top
  top=$(arm-none-eabi-nm "$elf" | awk '$NF == "__stack_top" { print $1 }')
  [ "$((16#${top:-0}))" -eq "$((expected))" ] \
    || fail "$(basename "$elf") stack top ${top:-missing} is not the RAM window end $(printf '%x' "$((expected))")"
}

# Runs an image on a QEMU Cortex-M machine; the exit code is the image's failure count.
qemu_run() {
  local machine="$1" elf="$2" log="$3" rc=0
  timeout "$qemu_timeout_s" qemu-system-arm -M "$machine" -display none -monitor none -serial none \
    -semihosting-config enable=on,target=native -kernel "$elf" > "$log" 2>&1 || rc=$?
  cat "$log"
  echo "qemu $machine exit $rc"
  return "$rc"
}

# Compares assert sites run per file with the `expect(` calls in each VECTOR_TESTS file.
check_vectors() {
  local runlog="$1" asserted=0 run=0 bad=0 t f a r golden listed in_tests=0
  local -a tests
  listed="$(vector_tests)"
  read -r -a tests <<< "$listed"
  [ "${#tests[@]}" -gt 0 ] || fail "VECTOR_TESTS is empty in cpp/Makefile"
  golden="$(tr -d '[:space:]' < "$root/fixtures/golden.hex")"
  for t in "${tests[@]}"; do
    f="$(basename "$t")"
    a=$(count_fixed "expect(" "$cpp/$t")
    r=$(awk -v f="$f" '$1 == "VECTORS_RUN" && $2 == f { v = $3 } END { print v + 0 }' "$runlog")
    in_tests=$((in_tests + $(count_fixed "$golden" "$cpp/$t")))
    echo "vectors $f asserted=$a run=$r"
    asserted=$((asserted + a))
    run=$((run + r))
    [ "$a" -eq "$r" ] || bad=$((bad + 1))
  done
  note "vectors run $run asserted $asserted"
  [ "$in_tests" -gt 0 ] || fail "fixtures/golden.hex row is not in the vector table"
  [ "$bad" -eq 0 ] || fail "$bad file(s) with vectors run != asserted"
  [ "$(log_value FAILURES "$runlog")" = 0 ] || fail "failures $(log_value FAILURES "$runlog")"
}

# The percentage packets a vector runner printed (`PERCENT_HEX <name> <hex>` lines, ecc_percent_tests.cpp), one
# `<name> <hex>` line each, to the file $2. Fewer than the 12 rows the test prints fails the target: an image that
# printed none must not pass the comparison between machines.
percent_packets() {
  local runlog="$1" file="$2" lines
  awk '$1 == "PERCENT_HEX" { print $2, $3 }' "$runlog" > "$file"
  lines=$(awk 'END { print NR }' "$file")
  [ "$lines" -ge 12 ] || fail "$(basename "$runlog") printed $lines percentage packet(s), expected at least 12"
}

target_m0plus() {
  local dir="$build/m0plus"
  local arch=(-mthumb -mcpu=cortex-m0plus -mfloat-abi=soft)
  arm_firmware_objects "$dir" "${arch[@]}"
  arm_link_ac2 "$dir" "${arch[@]}"
  image_checks "$dir" ac2
  note "AC-1 0 warnings; AC-2 link refs cxa=0 heap=0"
}

target_m3() {
  local dir="$build/m3"
  local arch=(-mthumb -mcpu=cortex-m3 -mfloat-abi=soft)
  arm_firmware_objects "$dir" "${arch[@]}"
  local t listed objs=()
  local -a tests
  listed="$(vector_tests)"
  read -r -a tests <<< "$listed"
  for t in "${tests[@]}"; do
    arm_cxx "$dir" "$cpp/$t" "test-$(basename "${t%.cpp}").o" "${arch[@]}"
    objs+=("$dir/test-$(basename "${t%.cpp}").o")
  done
  arm_cxx "$dir" "$here/common/vectors_main.cpp" vectors_main.o "${arch[@]}"
  [ "$(count_warnings "$dir/compile.log")" -eq 0 ] || fail "compile warnings in vector tests"

  arm_link_ac2 "$dir" "${arch[@]}"
  image_checks "$dir" ac2
  arm_link "$dir" vectors.elf "${arch[@]}" "${arm_link_common[@]}" --specs=nano.specs \
    --specs=rdimon.specs "$dir"/core-*.o "$dir/all_kinds.o" "$dir/all_kinds_rounds.o" "${objs[@]}" \
    "$dir/vectors_main.o" "$dir/startup.o"
  image_checks "$dir" vectors

  qemu_run mps2-an385 "$dir/ac2.elf" "$dir/ac2.run.log" || fail "AC-2 firmware exit $?"
  [ "$(log_value WRAPPER_CALLS "$dir/ac2.run.log")" = 0 ] || fail "malloc/new wrapper called"
  [ "$(log_value FAILURES "$dir/ac2.run.log")" = 0 ] || fail "AC-2 round trip failed"
  note "AC-2 cxa refs 0 heap refs 0 wrapper calls 0 mismatched fields $(log_value MISMATCHED_FIELDS "$dir/ac2.run.log")"

  qemu_run mps2-an385 "$dir/vectors.elf" "$dir/vectors.run.log" || fail "vector runner exit $?"
  check_vectors "$dir/vectors.run.log"
  note "AC-6 OS random refs 0"
  log_value ALL_KINDS_HEX "$dir/ac2.run.log" > "$out/m3-all-kinds.hex"
  [ "$(log_value ALL_KINDS_HEX "$dir/vectors.run.log")" = "$(cat "$out/m3-all-kinds.hex")" ] \
    || fail "all-kinds packet differs between the AC-2 firmware and the runner"
  percent_packets "$dir/vectors.run.log" "$out/m3-percent.hex"
  note "percentage packets printed: $(awk 'END { print NR }' "$out/m3-percent.hex")"
}

# The string-free, ECC-free build (PACKBIN_NO_TEXT and PACKBIN_NO_ECC together, the build of a board that only carries
# packets; AZ-3483) on the M33F: the core objects with both flags and the two host tests of that build, unchanged but
# for the renamed main, run as one image. Run-only: no flash or stack pin. The image links newlib stdio for the tests'
# output, so the heap and exception checks read the core objects (an allocator or exception reference is an undefined
# symbol there); the image checks cover OS random and the RAM window. Args: build dir, then the arch flags.
m33f_small_image() {
  local dir="$1/small" src t
  shift
  local small=(-DPACKBIN_NO_TEXT -DPACKBIN_NO_ECC)
  rm -rf "$dir"
  mkdir -p "$dir"
  : > "$dir/compile.log"
  for src in "${core_srcs[@]}"; do
    arm_cxx "$dir" "$cpp/$src" "core-$(basename "${src%.cpp}").o" "$@" "${small[@]}"
  done
  arm_cxx "$dir" "$cpp/tests/core/no_text_tests.cpp" no_text_tests.o "$@" "${small[@]}" -Dmain=run_no_text_tests
  arm_cxx "$dir" "$cpp/tests/core/no_ecc_tests.cpp" no_ecc_tests.o "$@" "${small[@]}" -Dmain=run_no_ecc_tests
  arm_cxx "$dir" "$here/arm/small_main.cpp" small_main.o "$@" "${small[@]}"
  arm_cc "$dir" "$here/arm/startup.c" startup.o "$@"
  [ "$(count_warnings "$dir/compile.log")" -eq 0 ] || fail "compile warnings in the string-free, ECC-free M33F objects"

  NM=arm-none-eabi-nm SIZE=arm-none-eabi-size sh "$cpp/tests/core/check-objects.sh" --no-text "$dir"/core-*.o \
    || fail "string-free M33F core objects hold a codec symbol, an allocator, an exception reference or writable data"
  NM=arm-none-eabi-nm SIZE=arm-none-eabi-size sh "$cpp/tests/core/check-objects.sh" --no-ecc "$dir"/core-*.o \
    || fail "ECC-free M33F core objects hold an ECC symbol, an allocator, an exception reference or writable data"

  arm_link "$dir" small.elf "$@" "${arm_link_common[@]}" --specs=nano.specs --specs=rdimon.specs \
    "$dir"/core-*.o "$dir/no_text_tests.o" "$dir/no_ecc_tests.o" "$dir/small_main.o" "$dir/startup.o"
  image_checks "$dir" small
  check_ram_end "$dir/small.elf" "$m33f_ram_end"
  qemu_run mps2-an505 "$dir/small.elf" "$dir/small.run.log" || fail "string-free, ECC-free image on M33F exit $?"
  [ "$(log_value FAILURES "$dir/small.run.log")" = 0 ] || fail "string-free, ECC-free image failures on M33F"
  local asserted run bad=0
  for t in no_text_tests.cpp no_ecc_tests.cpp; do
    asserted=$(count_fixed "expect(" "$cpp/tests/core/$t")
    run=$(awk -v f="$t" '$1 == "VECTORS_RUN" && $2 == f { v = $3 } END { print v + 0 }' "$dir/small.run.log")
    echo "small $t asserted=$asserted run=$run"
    [ "$asserted" -eq "$run" ] || bad=$((bad + 1))
  done
  [ "$bad" -eq 0 ] || fail "$bad file(s) of the string-free, ECC-free image with sites run != asserted"
  note "string-free, ECC-free M33F image: $(arm-none-eabi-size "$dir/small.elf" | awk 'NR == 2 { print $1 + $2 }') B flash (not pinned), core objects clean, sites run = asserted"
}

# Cortex-M33F, the nRF54L15 core (AZ-3189): the whole core (string codec and message error correction on) and the
# all-kinds scheme on QEMU mps2-an505, with the vector runner. Flash is the all-kinds image, stack is net of the meter
# overhead; both are held to the ceilings and pins in lib.sh (m33f_*).
target_m33f() {
  local dir="$build/m33f"
  local arch=(-mthumb -mcpu=cortex-m33 -mfloat-abi=hard -mfpu=fpv5-sp-d16)
  # Shadows the global of the M3 images for the link helpers below: the AN505 memory map has its own script.
  local arm_link_common=(-nostartfiles -T "$here/arm/mps2-an505.ld" -Wl,--gc-sections -Wl,--cref)
  arm_firmware_objects "$dir" "${arch[@]}"
  local t listed objs=()
  local -a tests
  listed="$(vector_tests)"
  read -r -a tests <<< "$listed"
  for t in "${tests[@]}"; do
    arm_cxx "$dir" "$cpp/$t" "test-$(basename "${t%.cpp}").o" "${arch[@]}"
    objs+=("$dir/test-$(basename "${t%.cpp}").o")
  done
  arm_cxx "$dir" "$here/common/vectors_main.cpp" vectors_main.o "${arch[@]}"
  arm_cxx "$dir" "$here/arm/baseline_main.cpp" baseline.o "${arch[@]}"
  arm_cxx "$dir" "$here/arm/frame_main.cpp" frame_main.o "${arch[@]}"
  [ "$(count_warnings "$dir/compile.log")" -eq 0 ] || fail "compile warnings in the M33F objects"

  arm_link_ac2 "$dir" "${arch[@]}"
  image_checks "$dir" ac2
  arm_link "$dir" vectors.elf "${arch[@]}" "${arm_link_common[@]}" --specs=nano.specs \
    --specs=rdimon.specs "$dir"/core-*.o "$dir/all_kinds.o" "$dir/all_kinds_rounds.o" "${objs[@]}" \
    "$dir/vectors_main.o" "$dir/startup.o"
  image_checks "$dir" vectors
  arm_link "$dir" baseline.elf "${arch[@]}" "${arm_link_common[@]}" --specs=nano.specs \
    --specs=nosys.specs "${heap_wraps[@]}" "$dir/baseline.o" "$dir/startup.o" "$dir/wrap.o"
  # The frame image (AZ-3292): the frame session and the MAC-only call alone, no pack or unpack in it.
  arm_link "$dir" frame.elf "${arch[@]}" "${arm_link_common[@]}" --specs=nano.specs \
    --specs=nosys.specs "${heap_wraps[@]}" "$dir"/core-*.o "$dir/frame_main.o" "$dir/startup.o" "$dir/wrap.o"
  image_checks "$dir" frame
  for t in ac2 vectors baseline frame; do check_ram_end "$dir/$t.elf" "$m33f_ram_end"; done

  qemu_run mps2-an505 "$dir/baseline.elf" "$dir/baseline.run.log" || fail "M33F baseline exit $?"
  qemu_run mps2-an505 "$dir/ac2.elf" "$dir/ac2.run.log" || fail "AC-2 firmware on M33F exit $?"
  [ "$(log_value WRAPPER_CALLS "$dir/ac2.run.log")" = 0 ] || fail "malloc/new wrapper called"
  [ "$(log_value FAILURES "$dir/ac2.run.log")" = 0 ] || fail "AC-2 round trip failed on M33F"
  qemu_run mps2-an505 "$dir/frame.elf" "$dir/frame.run.log" || fail "frame image on M33F exit $?"
  [ "$(log_value WRAPPER_CALLS "$dir/frame.run.log")" = 0 ] || fail "malloc/new wrapper called by the frame image"
  [ "$(log_value FAILURES "$dir/frame.run.log")" = 0 ] || fail "frame image failures on M33F"
  qemu_run mps2-an505 "$dir/vectors.elf" "$dir/vectors.run.log" || fail "M33F vector runner exit $?"
  check_vectors "$dir/vectors.run.log"
  # The packet the M33F image builds equals the one the Cortex-M3 image builds (target_m3 runs earlier in the stage).
  log_value ALL_KINDS_HEX "$dir/ac2.run.log" > "$out/m33f-all-kinds.hex"
  [ "$(cat "$out/m33f-all-kinds.hex")" = "$(log_value ALL_KINDS_HEX "$dir/vectors.run.log")" ] \
    || fail "all-kinds packet differs between the M33F AC-2 firmware and the runner"
  [ -f "$out/m3-all-kinds.hex" ] || fail "no Cortex-M3 packet to compare with ($out/m3-all-kinds.hex: cpp-m3-qemu runs first)"
  cmp -s "$out/m3-all-kinds.hex" "$out/m33f-all-kinds.hex" || fail "all-kinds packet differs between Cortex-M3 and Cortex-M33F"
  percent_packets "$dir/vectors.run.log" "$out/m33f-percent.hex"
  [ -f "$out/m3-percent.hex" ] || fail "no Cortex-M3 percentage packets to compare with ($out/m3-percent.hex: cpp-m3-qemu runs first)"
  cmp -s "$out/m3-percent.hex" "$out/m33f-percent.hex" || fail "percentage packets differ between Cortex-M3 and Cortex-M33F"

  local flash raw meter stack core_rw
  flash=$(arm-none-eabi-size "$dir/ac2.elf" | awk 'NR == 2 { print $1 + $2 }')
  raw=$(for f in ac2; do
    log_value PACK_STACK "$dir/$f.run.log"
    log_value UNPACK_STACK "$dir/$f.run.log"
  done | sort -n | tail -n 1)
  meter=$(log_value PACK_STACK "$dir/baseline.run.log")
  stack=$((raw - meter))
  core_rw=$(arm-none-eabi-size "$dir"/core-*.o | awk 'FNR > 1 { s += $2 + $3 } END { print s + 0 }')
  echo "m33f all-kinds image flash=$flash budget=$m33f_flash_budget pin=$m33f_flash_pin"
  echo "m33f stack raw=$raw meter overhead=$meter net=$stack budget=$m33f_stack_budget pin=$m33f_stack_pin"
  note "Cortex-M33F whole core: all-kinds image flash ${flash} B of ${m33f_flash_budget} (pin ${m33f_flash_pin} B)"
  note "deepest pack/unpack stack ${stack} B of ${m33f_stack_budget} (pin ${m33f_stack_pin} B; raw ${raw} B less ${meter} B meter overhead)"
  note "core data+bss ${core_rw} B"
  [ "$flash" -le "$m33f_flash_budget" ] || fail "M33F flash ${flash} B over ${m33f_flash_budget} B"
  [ "$flash" -le "$m33f_flash_pin" ] || fail "M33F flash ${flash} B measured is over the pin of ${m33f_flash_pin} B (cpp/embedded/lib.sh m33f_flash_pin)"
  [ "$stack" -le "$m33f_stack_budget" ] || fail "M33F stack ${stack} B over ${m33f_stack_budget} B"
  [ "$stack" -le "$m33f_stack_pin" ] || fail "M33F stack ${stack} B measured is over the pin of ${m33f_stack_pin} B (cpp/embedded/lib.sh m33f_stack_pin)"
  [ "$core_rw" -eq 0 ] || fail "M33F core data+bss ${core_rw} B"

  # The frame image: its flash is the image (text plus data), its stack the deepest call of the image net of the
  # meter overhead; both are held to the ceilings above and to their own pins (AZ-3292).
  local frame_flash frame_raw frame_stack
  frame_flash=$(arm-none-eabi-size "$dir/frame.elf" | awk 'NR == 2 { print $1 + $2 }')
  frame_raw=$(log_value FRAME_STACK "$dir/frame.run.log")
  frame_stack=$((frame_raw - meter))
  echo "m33f frame image flash=$frame_flash budget=$m33f_flash_budget pin=$m33f_frame_flash_pin"
  echo "m33f frame stack raw=$frame_raw meter overhead=$meter net=$frame_stack budget=$m33f_stack_budget pin=$m33f_frame_stack_pin"
  note "Cortex-M33F frame image flash ${frame_flash} B of ${m33f_flash_budget} (pin ${m33f_frame_flash_pin} B)"
  note "deepest frame call stack ${frame_stack} B of ${m33f_stack_budget} (pin ${m33f_frame_stack_pin} B; raw ${frame_raw} B less ${meter} B meter overhead)"
  [ "$frame_flash" -le "$m33f_flash_budget" ] || fail "M33F frame flash ${frame_flash} B over ${m33f_flash_budget} B"
  [ "$frame_flash" -le "$m33f_frame_flash_pin" ] || fail "M33F frame flash ${frame_flash} B measured is over the pin of ${m33f_frame_flash_pin} B (cpp/embedded/lib.sh m33f_frame_flash_pin)"
  [ "$frame_stack" -le "$m33f_stack_budget" ] || fail "M33F frame stack ${frame_stack} B over ${m33f_stack_budget} B"
  [ "$frame_stack" -le "$m33f_frame_stack_pin" ] || fail "M33F frame stack ${frame_stack} B measured is over the pin of ${m33f_frame_stack_pin} B (cpp/embedded/lib.sh m33f_frame_stack_pin)"

  m33f_small_image "$dir" "${arch[@]}"
}

target_s390x() {
  local dir="$build/s390x"
  rm -rf "$dir"
  mkdir -p "$dir"
  local listed
  local -a tests srcs
  listed="$(vector_tests)"
  read -r -a tests <<< "$listed"
  srcs=("${core_srcs[@]/#/$cpp/}" "${tests[@]/#/$cpp/}" "$here/common/all_kinds.cpp"
    "$here/common/all_kinds_rounds.cpp" "$here/common/vectors_main.cpp")
  local status=0
  s390x-linux-gnu-g++ "${core_flags[@]}" -static -I"$cpp/include" -I"$cpp/tests/core" \
    -I"$here/common" -o "$dir/vectors" "${srcs[@]}" 2>&1 | tee "$dir/compile.log" || status=$?
  if [ "$status" -ne 0 ]; then
    fail "s390x build exit $status"
    return 1
  fi
  [ "$(count_warnings "$dir/compile.log")" -eq 0 ] || fail "compile warnings"
  local rc=0
  (cd "$cpp" && qemu-s390x-static "$dir/vectors") > "$dir/run.log" 2>&1 || rc=$?
  cat "$dir/run.log"
  [ "$rc" -eq 0 ] || fail "big-endian run exit $rc"
  [ "$(log_value ENDIAN "$dir/run.log")" = big ] || fail "not a big-endian CPU"
  check_vectors "$dir/run.log"
  if [ -s "$out/m3-all-kinds.hex" ]; then
    [ "$(log_value ALL_KINDS_HEX "$dir/run.log")" = "$(cat "$out/m3-all-kinds.hex")" ] \
      || fail "all-kinds packet differs from Cortex-M3"
    note "AC-4 all-kinds packet equals Cortex-M3 bytes"
  else
    note "all-kinds cross-check not done: no Cortex-M3 packet (see cpp-m3-qemu row)"
  fi
  # The percentage packets (loop 97) are compared with the Cortex-M3 file as target_m33f does; a missing file is
  # reported the way the all-kinds check reports it, so a single-row run still passes.
  percent_packets "$dir/run.log" "$out/s390x-percent.hex"
  if [ -s "$out/m3-percent.hex" ]; then
    cmp -s "$out/m3-percent.hex" "$out/s390x-percent.hex" || fail "percentage packets differ between Cortex-M3 and s390x"
    note "percentage packets equal Cortex-M3 bytes"
  else
    note "percentage cross-check not done: no Cortex-M3 percentage packets (see cpp-m3-qemu row)"
  fi
}

# AVR: the core on an ATmega328P (Arduino Uno) with avr-gcc 7.3, which has no C++ library and a 4-byte
# double (AZ-2068). The Uno example is built only; one other image, avr/chacha20_check.cpp, runs on simavr
# and checks chacha20_xor on a 16-bit int and size_t (AZ-3452).
avr_arch=(-mmcu=atmega328p)
# ATmega328P: 32 KB of flash less the 512 B Uno boot loader, 2 KB of RAM (static data and stack).
avr_flash_budget=32256
avr_ram_budget=2048

avr_cxx() {
  local dir="$1" src="$2" obj="$3" status=0
  shift 3
  avr-g++ "${core_flags[@]}" "${avr_arch[@]}" "$@" -ffunction-sections -fdata-sections \
    -I"$cpp/include" -c "$src" -o "$dir/$obj" 2>&1 | tee -a "$dir/compile.log" || status=$?
  if [ "$status" -ne 0 ]; then
    fail "compile $(basename "$src") exit $status"
    return 1
  fi
}

# AZ-3452 AC-1 to AC-6: links the check image and runs it on simavr (ATmega328P, 16 MHz). What it prints on
# the UART, less simavr's colour codes and notices, must equal avr/chacha20_expected.txt line for line: a
# failing case, a wrong count, a missing line or no output at all fails the row, and so does a run that does
# not end within 30 s or a missing simavr.
avr_run_chacha20() {
  local dir="$1" status=0 elf="$1/avr_chacha20.elf" raw="$1/chacha20.raw" got="$1/chacha20.out"
  avr-g++ "${core_flags[@]}" "${avr_arch[@]}" -Wl,--gc-sections -o "$elf" \
    "$dir/chacha20/check.o" "$dir/uno/core-crypto.o" 2>&1 | tee "$dir/chacha20-link.log" || status=$?
  if [ "$status" -ne 0 ]; then
    fail "link avr_chacha20.elf exit $status"
    return 1
  fi
  [ "$(count_warnings "$dir/chacha20-link.log")" -eq 0 ] || fail "link warnings in avr_chacha20.elf"
  local flash ram
  flash=$(avr-size "$elf" | awk 'NR == 2 { print $1 + $2 }')
  ram=$(avr-size "$elf" | awk 'NR == 2 { print $2 + $3 }')
  [ "$flash" -le "$avr_flash_budget" ] || fail "chacha20 image flash $flash B over $avr_flash_budget B"
  [ "$ram" -le "$avr_ram_budget" ] || fail "chacha20 image static RAM $ram B over $avr_ram_budget B"
  if ! command -v simavr > /dev/null; then
    fail "AZ-3452 AC-5 simavr is missing from the image"
    return 0
  fi
  timeout 30 simavr -m atmega328p -f 16000000 "$elf" > "$raw" 2>&1 < /dev/null || status=$?
  # simavr shows the end of each UART line as a dot and wraps the line in colour codes; its own notices
  # (`Loaded ...`) do not end in a dot.
  sed 's/\x1b\[[0-9;]*m//g' "$raw" | sed -n 's/\.$//p' > "$got"
  if [ "$status" -eq 124 ]; then
    fail "AZ-3452 AC-5 chacha20 image did not end within 30 s"
  elif [ "$status" -ne 0 ]; then
    fail "AZ-3452 AC-5 simavr exit $status"
  elif ! diff "$here/avr/chacha20_expected.txt" "$got" > "$dir/chacha20.diff"; then
    cat "$dir/chacha20.diff"
    fail "AZ-3452 AC-5 chacha20 report differs from avr/chacha20_expected.txt"
  else
    note "AZ-3452 AC-1 to AC-4 chacha20_xor on a 16-bit size_t under simavr: $(tr '\n' ',' < "$got" | sed 's/,$//'); image flash $flash B static RAM $ram B"
  fi
}

target_avr_uno() {
  local dir="$build/avr" src
  rm -rf "$dir"
  mkdir -p "$dir/full" "$dir/uno" "$dir/chacha20"
  : > "$dir/compile.log"
  # AC-1: the whole core, string codec and parity included, compiles with 0 warnings.
  for src in "${core_srcs[@]}"; do
    avr_cxx "$dir" "$cpp/$src" "full/$(basename "${src%.cpp}").o"
  done
  # The Uno example leaves out the string and parity tables: constant tables sit in RAM on AVR.
  local small=(-DPACKBIN_NO_TEXT -DPACKBIN_NO_ECC)
  for src in "${core_srcs[@]}"; do
    avr_cxx "$dir" "$cpp/$src" "uno/core-$(basename "${src%.cpp}").o" "${small[@]}"
  done
  avr_cxx "$dir" "$cpp/examples/avr_uno/avr_uno.cpp" uno/avr_uno.o "${small[@]}"
  avr_cxx "$dir" "$here/avr/chacha20_check.cpp" chacha20/check.o -I"$cpp/src" "${small[@]}"
  local warnings
  warnings=$(count_warnings "$dir/compile.log")
  echo "compile warnings: $warnings"
  [ "$warnings" -eq 0 ] || fail "$warnings compile warning(s)"

  local status=0
  avr-g++ "${core_flags[@]}" "${avr_arch[@]}" -Wl,--gc-sections -o "$dir/avr_uno.elf" \
    "$dir"/uno/*.o 2>&1 | tee "$dir/link.log" || status=$?
  if [ "$status" -ne 0 ]; then
    fail "link avr_uno.elf exit $status"
    return 1
  fi
  [ "$(count_warnings "$dir/link.log")" -eq 0 ] || fail "link warnings in avr_uno.elf"
  avr-size "$dir/avr_uno.elf"
  local flash ram
  flash=$(avr-size "$dir/avr_uno.elf" | awk 'NR == 2 { print $1 + $2 }')
  ram=$(avr-size "$dir/avr_uno.elf" | awk 'NR == 2 { print $2 + $3 }')
  [ "$flash" -le "$avr_flash_budget" ] || fail "Uno flash $flash B over $avr_flash_budget B"
  [ "$ram" -le "$avr_ram_budget" ] || fail "Uno static RAM $ram B over $avr_ram_budget B"
  note "AC-1 0 warnings; Uno example flash $flash B of $avr_flash_budget static RAM $ram B of $avr_ram_budget"

  avr_run_chacha20 "$dir"

  # AC-2: a scheme with f64 does not compile, and the message names f64.
  status=0
  avr-g++ "${core_flags[@]}" "${avr_arch[@]}" -I"$cpp/include" -fsyntax-only \
    "$here/avr/f64_refused.cpp" > "$dir/f64.log" 2>&1 || status=$?
  if [ "$status" -eq 0 ]; then
    fail "AC-2 a scheme with f64 compiled"
  elif grep -q 'f64 needs an 8-byte double' "$dir/f64.log"; then
    note "AC-2 f64 refused"
  else
    cat "$dir/f64.log"
    fail "AC-2 f64 refused without naming f64"
  fi

  # Without __builtin_is_constant_evaluated a broken constant scheme compiles; its status names it.
  status=0
  avr-g++ "${core_flags[@]}" "${avr_arch[@]}" -I"$cpp/include" -fsyntax-only \
    "$here/avr/broken_scheme_status.cpp" > "$dir/broken.log" 2>&1 || status=$?
  if [ "$status" -eq 0 ]; then
    note "broken constant scheme is SchemeInvalid"
  else
    cat "$dir/broken.log"
    fail "broken constant scheme: status check did not compile"
  fi
}
