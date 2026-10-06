#!/usr/bin/env bash
# Cortex-M and big-endian targets (packbin-embedded image). Sourced by run.sh after lib.sh.
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

# Core objects (with -fstack-usage), the all-kinds scheme and the AC-2 firmware objects.
arm_firmware_objects() {
  local dir="$1"
  shift
  rm -rf "$dir"
  mkdir -p "$dir"
  : > "$dir/compile.log"
  local src
  for src in "${core_srcs[@]}"; do
    arm_cxx "$dir" "$cpp/$src" "core-$(basename "${src%.cpp}").o" "$@" -fstack-usage
  done
  arm_cxx "$dir" "$here/common/all_kinds.cpp" all_kinds.o "$@"
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
    "${heap_wraps[@]}" "$dir"/core-*.o "$dir/all_kinds.o" "$dir/ac2_main.o" "$dir/startup.o" \
    "$dir/wrap.o"
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
  osrnd=$(awk '$NF ~ /(getrandom|arc4random|os_random)/ { n++ } END { print n + 0 }' "$syms")
  urandom=$(count_fixed "/dev/urandom" "$elf")
  echo "$stem: __cxa_throw=$throw __cxa_allocate_exception=$alloc heap_symbols=$heap os_random_symbols=$osrnd dev_urandom=$urandom"
  [ "$((throw + alloc))" -eq 0 ] || fail "$stem references exceptions ($throw throw $alloc allocate)"
  [ "$osrnd" -eq 0 ] && [ "$urandom" -eq 0 ] || fail "$stem references OS random"
  if [ "$stem" = ac2 ]; then
    [ "$heap" -eq 0 ] || fail "ac2 references the heap ($heap symbol(s))"
  fi
  printf '%s %s %s %s\n' "$throw" "$alloc" "$heap" "$((osrnd + urandom))" > "$dir/$stem.refs"
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
    --specs=rdimon.specs "$dir"/core-*.o "$dir/all_kinds.o" "${objs[@]}" \
    "$dir/vectors_main.o" "$dir/startup.o"
  image_checks "$dir" vectors

  qemu_run mps2-an385 "$dir/ac2.elf" "$dir/ac2.run.log" || fail "AC-2 firmware exit $?"
  [ "$(log_value WRAPPER_CALLS "$dir/ac2.run.log")" = 0 ] || fail "malloc/new wrapper called"
  [ "$(log_value FAILURES "$dir/ac2.run.log")" = 0 ] || fail "AC-2 round trip failed"
  note "AC-2 cxa refs 0 heap refs 0 wrapper calls 0 mismatched fields $(log_value MISMATCHED_FIELDS "$dir/ac2.run.log")"

  qemu_run mps2-an385 "$dir/vectors.elf" "$dir/vectors.run.log" || fail "vector runner exit $?"
  check_vectors "$dir/vectors.run.log"
  note "AC-6 session vectors $(awk '$1 == "VECTORS_RUN" && $2 == "session_tests.cpp" { print $3 }' "$dir/vectors.run.log") run and OS random refs 0"
  log_value ALL_KINDS_HEX "$dir/ac2.run.log" > "$out/m3-all-kinds.hex"
  [ "$(log_value ALL_KINDS_HEX "$dir/vectors.run.log")" = "$(cat "$out/m3-all-kinds.hex")" ] \
    || fail "all-kinds packet differs between the AC-2 firmware and the runner"
}

# Largest single frame in the core's -fstack-usage files.
max_frame() {
  cat "$1"/core-*.su | awk -F'\t' '{ if ($2 + 0 > m) { m = $2 + 0; f = $1 } } END { print m + 0, f }'
}

target_m4f() {
  local dir="$build/m4f"
  local arch=(-mthumb -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16)
  arm_firmware_objects "$dir" "${arch[@]}"
  arm_cxx "$dir" "$here/arm/size_main.cpp" size14.o "${arch[@]}"
  arm_cxx "$dir" "$here/arm/size_main.cpp" baseline.o "${arch[@]}" -DPACKBIN_SIZE_BASELINE
  [ "$(count_warnings "$dir/compile.log")" -eq 0 ] || fail "compile warnings in size probe"

  arm_link_ac2 "$dir" "${arch[@]}"
  image_checks "$dir" ac2
  local probe
  for probe in size14 baseline; do
    arm_link "$dir" "$probe.elf" "${arch[@]}" "${arm_link_common[@]}" --specs=nano.specs \
      --specs=nosys.specs "${heap_wraps[@]}" "$dir"/core-*.o "$dir/$probe.o" "$dir/startup.o" \
      "$dir/wrap.o"
    qemu_run mps2-an386 "$dir/$probe.elf" "$dir/$probe.run.log" || fail "$probe exit $?"
  done
  qemu_run mps2-an386 "$dir/ac2.elf" "$dir/ac2.run.log" || fail "AC-2 firmware on M4F exit $?"

  local flash14 flash0 delta core_rw raw meter stack frame
  flash14=$(arm-none-eabi-size "$dir/size14.elf" | awk 'NR == 2 { print $1 + $2 }')
  flash0=$(arm-none-eabi-size "$dir/baseline.elf" | awk 'NR == 2 { print $1 + $2 }')
  delta=$((flash14 - flash0))
  echo "core objects (text data bss):"
  arm-none-eabi-size "$dir"/core-*.o | tee "$out/m4f-core-size.txt"
  core_rw=$(awk 'NR > 1 { s += $2 + $3 } END { print s + 0 }' "$out/m4f-core-size.txt")
  raw=$(for f in size14 ac2; do
    log_value PACK_STACK "$dir/$f.run.log"
    log_value UNPACK_STACK "$dir/$f.run.log"
  done | sort -n | tail -n 1)
  # The meter reads its own unpainted guard as used; the baseline image measures an empty
  # call, so its reading is the meter's overhead.
  meter=$(log_value PACK_STACK "$dir/baseline.run.log")
  stack=$((raw - meter))
  echo "stack raw=$raw meter overhead=$meter"
  frame=$(max_frame "$dir")
  cat "$dir"/core-*.su > "$out/m4f-core.su"
  echo "size14 flash=$flash14 baseline flash=$flash0 delta=$delta budget=$flash_budget"
  echo "deepest measured pack/unpack stack=$stack budget=$stack_budget (largest core frame: $frame)"
  echo "core .data+.bss=$core_rw"
  note "AC-5 flash core+14-field table ${delta} B of ${flash_budget}"
  note "deepest pack/unpack stack ${stack} B of ${stack_budget} (raw ${raw} B less ${meter} B meter overhead)"
  note "largest single core frame ${frame%% *} B"
  note "core data+bss ${core_rw} B; all-kinds image $(arm-none-eabi-size "$dir/ac2.elf" | awk 'NR == 2 { print $1 + $2 }') B flash"
  [ "$(log_value FAILURES "$dir/size14.run.log")" = 0 ] || fail "size probe round trip"
  [ "$(log_value FAILURES "$dir/ac2.run.log")" = 0 ] || fail "AC-2 round trip on M4F"
  [ "$delta" -le "$flash_budget" ] || fail "flash ${delta} B over ${flash_budget} B"
  [ "$stack" -le "$stack_budget" ] || fail "stack ${stack} B over ${stack_budget} B"
  [ "$core_rw" -eq 0 ] || fail "core data+bss ${core_rw} B"
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
    "$here/common/vectors_main.cpp")
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
}
