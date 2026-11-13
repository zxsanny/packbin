#!/usr/bin/env bash
# Self-test of the embedded harness (AZ-2099). Runs the real run.sh, lib.sh and report-row.sh from a
# temp tree against fake targets and checks the report rows, the logs and the stage exit code.
# lib.sh times a target with date +%s%N, which only GNU date has: the scaffold job runs it as is, and on the Mac a
# `date` shim (below) answers that one call.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

# The file:line of every `find ... | head` command in the harness scripts (AZ-2238 AC-3). Under pipefail head
# closes the pipe, a find that still has output gets SIGPIPE, and the pipeline ends with status 141, which
# set -e turns into a silent exit of the stage. A scan, not a run: the two examples.sh functions that had it
# need pio, compote and idf.py, which only the espressif/idf image has. Comment lines are skipped, lines
# that end in a backslash or a pipe join the next line, and the line reported is the first of the command.
find_head_hits() {
  local file
  for file in "$here"/*.sh; do
    case "$file" in
      *.test.sh) continue ;;
    esac
    awk -v name="$(basename "$file")" '
      { if (joined == "") first = NR
        line = $0
        more = sub(/\\[ \t]*$/, "", line) || line ~ /\|[ \t]*$/
        joined = joined " " line
        if (more) next
        if (joined !~ /^[ \t]*#/ && joined ~ /find.*\|[ \t]*head([^a-zA-Z0-9_-]|$)/) print name ":" first
        joined = "" }
    ' "$file"
  done
}

find_head="$(find_head_hits)"
if [ -n "$find_head" ]; then
  echo "FAIL find | head under pipefail in the embedded harness: $(tr '\n' ' ' <<< "$find_head")" >&2
  exit 1
fi
echo "PASS no find | head in the embedded harness scripts"

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
case "$(date +%s%N)" in
  *[!0-9]*)
    cat > "$tmp/bin/date" <<'SHIM'
#!/usr/bin/env bash
if [ "${1:-}" = +%s%N ]; then
  exec perl -MTime::HiRes=gettimeofday -e '($s, $us) = gettimeofday; printf "%d%06d000\n", $s, $us'
fi
exec /bin/date "$@"
SHIM
    chmod +x "$tmp/bin/date"
    ;;
esac
export PATH="$tmp/bin:$PATH"
failures=0
scenario_failed=0
stage_rc=0
tree=""

# A temp SRC_ROOT with the real harness files; the scenario writes the fake arm.sh.
new_tree() {
  tree="$tmp/$1"
  mkdir -p "$tree/cpp/embedded" "$tree/.github/workflows"
  cp "$here/run.sh" "$here/lib.sh" "$tree/cpp/embedded/"
  cp "$repo/.github/workflows/report-row.sh" "$tree/.github/workflows/"
}

# Runs `run.sh <stage>` in $tree as a separate process and keeps its output and exit code.
run_stage() {
  stage_rc=0
  SRC_ROOT="$tree" TEST_RESULTS="$tree/results" bash "$tree/cpp/embedded/run.sh" "$1" \
    > "$tree/stage.out" 2>&1 || stage_rc=$?
}

check() {
  local label="$1"
  shift
  if "$@"; then
    echo "PASS $label"
  else
    echo "FAIL $label" >&2
    failures=$((failures + 1))
    scenario_failed=1
  fi
}

# After a scenario with a failed check: what the stage printed and what the report holds.
show_evidence() {
  if [ "$scenario_failed" -ne 0 ]; then
    sed 's/^/  stage: /' "$tree/stage.out" >&2
    sed 's/^/  report: /' "$tree/results/report.csv" >&2
    scenario_failed=0
  fi
}

# The last report row of target $1 matches the extended regex $2.
row_matches() {
  awk -F, -v id="$1" '$1 == id { row = $0 } END { print row }' "$tree/results/report.csv" | grep -Eq "$2"
}

rows() {
  [ "$(($(wc -l < "$tree/results/report.csv") - 1))" -eq "$1" ]
}

log_lacks() {
  ! grep -q "$2" "$tree/results/embedded/$1.log"
}

log_has() {
  grep -q "$2" "$tree/results/embedded/$1.log"
}

rc_is() {
  [ "$stage_rc" -eq "$1" ]
}

stage_says() {
  grep -q "$1" "$tree/stage.out"
}

ac1_unchecked_failure_fails_the_target() {
  new_tree ac1
  cat > "$tree/cpp/embedded/arm.sh" <<'EOF'
helper_copy() { cp "$out/does-not-exist" "$out/copy"; note "after cp"; }
target_m0plus() { false; note "after false"; }
target_m3() { helper_copy; }
target_m33f() { false | cat; note "after pipe"; }
target_s390x() { note "ran after the failures"; }
target_avr_uno() { note "ok"; }
EOF
  run_stage arm
  check "AC-1 false: row FAIL with exit status and log path" \
    row_matches cpp-m0plus '^cpp-m0plus,.*,FAIL,exit 1 \(log: test-results/embedded/cpp-m0plus\.log\)$'
  check "AC-1 false: the command after it did not run" log_lacks cpp-m0plus "after false"
  check "AC-1 failing cp in a helper: row FAIL" \
    row_matches cpp-m3-qemu '^cpp-m3-qemu,.*,FAIL,exit 1 \(log: test-results/embedded/cpp-m3-qemu\.log\)$'
  check "AC-1 failing cp in a helper: the command after it did not run" log_lacks cpp-m3-qemu "after cp"
  check "AC-1 failing pipeline (pipefail): row FAIL" row_matches cpp-m33f ',FAIL,exit 1 \(log:'
  check "AC-1 failing pipeline (pipefail): the command after it did not run" log_lacks cpp-m33f "after pipe"
  check "F3 false: the log names the failed command and its status" \
    log_has cpp-m0plus "target command failed: false (exit 1"
  check "F3 failing cp in a helper: the log names the cp" \
    log_has cpp-m3-qemu "target command failed: cp .*does-not-exist.* (exit 1"
  check "F3 failing pipeline: the log shows the status of every member" \
    log_has cpp-m33f "(exit 1, pipe 1 0)"
  check "AC-1 the stage exit code is 1" rc_is 1
  check "AC-4 the target after the failed ones still ran and passed" \
    row_matches cpp-s390x ',PASS,ran after the failures; $'
  check "AC-4 one row per target" rows 5
  check "AC-4 the stage reports 3 failed targets" stage_says "embedded stage arm: 3 target(s) failed"
  show_evidence
}

ac2_explicit_checks_continue() {
  new_tree ac2
  cat > "$tree/cpp/embedded/arm.sh" <<'EOF'
target_m0plus() { fail "budget A"; note "between"; fail "budget B"; note "after"; }
target_m3() { ( fail "from a subshell" ); note "after the subshell"; }
target_m33f() { note "before exit"; exit 3; }
target_s390x() { note "ok"; }
target_avr_uno() { note "ok"; }
EOF
  run_stage arm
  check "AC-2 both reasons in one FAIL row, later commands ran" \
    row_matches cpp-m0plus \
    ',FAIL,FAIL budget A; between; FAIL budget B; after; \(log: test-results/embedded/cpp-m0plus\.log\)$'
  check "AC-2 the command after the checks ran" log_has cpp-m0plus "NOTE after"
  check "F3 explicit fail checks leave no failed-command line" log_lacks cpp-m0plus "target command failed"
  check "AC-2 a fail inside a subshell still fails the target" \
    row_matches cpp-m3-qemu ',FAIL,FAIL from a subshell; after the subshell; \(log:'
  check "AC-1 an exit status is shown after the notes" \
    row_matches cpp-m33f ',FAIL,before exit; exit 3 \(log:'
  check "AC-2 the stage exit code is 1" rc_is 1
  show_evidence
}

ac3_passing_target_passes() {
  new_tree ac3
  cat > "$tree/cpp/embedded/arm.sh" <<'EOF'
target_m0plus() { note "FAILURES 0"; if false; then :; fi; false || true; [ 1 -eq 2 ] || true; ! false; }
target_m3() { note "ok"; }
target_m33f() { note "ok"; }
target_s390x() { note "ok"; }
target_avr_uno() { note "ok"; }
EOF
  run_stage arm
  check "F3 failures inside if, || and ! leave no failed-command line" \
    log_lacks cpp-m0plus "target command failed"
  check "AC-3 FAIL in an ordinary note does not fail the target" \
    row_matches cpp-m0plus ',PASS,FAILURES 0; $'
  check "AC-3 all five rows PASS" rows 5
  check "AC-3 the stage exit code is 0" rc_is 0
  check "AC-3 the stage reports 0 failed targets" stage_says "embedded stage arm: 0 target(s) failed"
  show_evidence
}

# Same temp tree and results folder as the AC-2 scenario, whose first target left a failure marker.
earlier_failure_marker_does_not_fail_a_rerun() {
  new_tree ac2
  cat > "$tree/cpp/embedded/arm.sh" <<'EOF'
target_m0plus() { note "ok"; }
target_m3() { note "ok"; }
target_m33f() { note "ok"; }
target_s390x() { note "ok"; }
target_avr_uno() { note "ok"; }
EOF
  run_stage arm
  check "a stale failure marker from the earlier run is cleared" row_matches cpp-m0plus ',PASS,ok; $'
  check "the rerun exits 0" rc_is 0
  show_evidence
}

usage_error_exits_2() {
  new_tree usage
  run_stage bogus
  check "usage error exits 2" rc_is 2
  check "usage error prints the usage line" stage_says "usage:"
  show_evidence
}

errexit_ignoring_call_is_refused() {
  new_tree guard
  local rc=0
  SRC_ROOT="$tree" TEST_RESULTS="$tree/results" bash -c '
    source "$1/cpp/embedded/lib.sh"
    target_x() { false; note "after"; }
    run_target x "x" target_x || true
  ' _ "$tree" > "$tree/stage.out" 2>&1 || rc=$?
  stage_rc=$rc
  check "run_target called from an || list is refused (exit 2)" rc_is 2
  check "the refusal says errexit is ignored" stage_says "errexit is ignored"
  show_evidence
}

# The big-endian row against stub tools (AZ-4261): the real target_s390x from arm.sh with a stub make, compiler and
# QEMU. The QEMU stub prints $tree/qemu.out, a vector run of one file with 12 percentage packets (r1..r12) and the
# all-kinds packet abcd; the scenario leaves the Cortex-M3 percentage file in the results folder as the variant says:
# equal, differ (one packet changed) or absent.
s390x_stub_tools() {
  local tool
  printf '#!/usr/bin/env bash\necho tests/core/a.cpp\n' > "$tmp/bin/make"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/s390x-linux-gnu-g++"
  printf '#!/usr/bin/env bash\ncat "$STUB_QEMU_OUT"\n' > "$tmp/bin/qemu-s390x-static"
  for tool in make s390x-linux-gnu-g++ qemu-s390x-static; do chmod +x "$tmp/bin/$tool"; done
}

s390x_scenario() {
  local variant="$1" i m3
  new_tree "s390x_$variant"
  cp "$here/arm.sh" "$tree/cpp/embedded/"
  mkdir -p "$tree/cpp/tests/core" "$tree/fixtures" "$tree/results/embedded"
  m3="$tree/results/embedded/m3-percent.hex"
  echo deadbeef > "$tree/fixtures/golden.hex"
  printf '// deadbeef\nexpect(1);\n' > "$tree/cpp/tests/core/a.cpp"
  {
    echo "ENDIAN big"
    echo "VECTORS_RUN a.cpp 1"
    echo "ALL_KINDS_HEX abcd"
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do echo "PERCENT_HEX r$i 0a0b$i"; done
    echo "FAILURES 0"
  } > "$tree/qemu.out"
  echo abcd > "$tree/results/embedded/m3-all-kinds.hex"
  if [ "$variant" != absent ]; then
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do echo "r$i 0a0b$i"; done > "$m3"
  fi
  if [ "$variant" = differ ]; then
    sed 's/^r7 0a0b7$/r7 0a0bff/' "$m3" > "$m3.tmp"
    mv "$m3.tmp" "$m3"
  fi
  s390x_stub_tools
  stage_rc=0
  SRC_ROOT="$tree" TEST_RESULTS="$tree/results" STUB_QEMU_OUT="$tree/qemu.out" bash -c '
    source "$1/cpp/embedded/lib.sh"
    source "$1/cpp/embedded/arm.sh"
    run_target cpp-s390x "s390x" target_s390x
  ' _ "$tree" > "$tree/stage.out" 2>&1 || stage_rc=$?
}

s390x_percentage_packets_are_compared_with_cortex_m3() {
  s390x_scenario equal
  check "s390x equal percentage packets: the row PASSes" row_matches cpp-s390x ',PASS,'
  check "s390x equal percentage packets: the note says so" log_has cpp-s390x "NOTE percentage packets equal Cortex-M3 bytes"
  show_evidence

  s390x_scenario differ
  check "s390x differing percentage packet: the row FAILs" row_matches cpp-s390x ',FAIL,'
  check "s390x differing percentage packet: the failure names the packets" \
    log_has cpp-s390x "FAIL percentage packets differ between Cortex-M3 and s390x"
  show_evidence

  s390x_scenario absent
  check "s390x without the M3 percentage file: the row PASSes" row_matches cpp-s390x ',PASS,'
  check "s390x without the M3 percentage file: reported as not done, as the all-kinds check does" \
    log_has cpp-s390x "NOTE percentage cross-check not done: no Cortex-M3 percentage packets"
  show_evidence
}

# The Arduino-ESP32 core pin (AZ-4261): arduino_esp32_core of examples.sh against a stub arduino-cli. The stub logs its
# arguments to $tree/arduino.log and answers `core list` with the version in $1; the pin is the one tool-pins.txt line
# of the temp tree (3.3.12).
esp_core_scenario() {
  new_tree "esp_core_$1"
  cp "$here/examples.sh" "$tree/cpp/embedded/"
  cp "$repo/.github/workflows/tool-pin.sh" "$tree/.github/workflows/"
  printf 'arduino-esp32==3.3.12\n' > "$tree/.github/workflows/tool-pins.txt"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$STUB_LOG"\nif [ "$1 $2" = "core list" ]; then\n  printf "ID Installed Latest Name\\nesp32:esp32 %%s 3.3.13 esp32\\n" "$STUB_CORE"\nfi\n' \
    > "$tmp/bin/arduino-cli"
  chmod +x "$tmp/bin/arduino-cli"
  SRC_ROOT="$tree" TEST_RESULTS="$tree/results" STUB_LOG="$tree/arduino.log" STUB_CORE="$1" bash -c '
    source "$1/cpp/embedded/lib.sh"
    source "$1/cpp/embedded/examples.sh"
    esp_core_target() { arduino_esp32_core; }
    run_target esp-core "esp core" esp_core_target
  ' _ "$tree" > "$tree/stage.out" 2>&1 || stage_rc=$?
}

arduino_esp32_core_is_the_pin() {
  esp_core_scenario 3.3.12
  check "esp core at the pin: the row PASSes" row_matches esp-core ',PASS,'
  check "esp core at the pin: the version in use is printed" log_has esp-core "Arduino-ESP32 core 3.3.12 (pin 3.3.12)"
  check "esp core at the pin: the install asks for the pinned version" \
    grep -q '^core install esp32:esp32@3.3.12 ' "$tree/arduino.log"
  show_evidence

  esp_core_scenario 3.3.13
  check "esp core newer than the pin: the row FAILs" row_matches esp-core ',FAIL,'
  check "esp core newer than the pin: the failure names both versions" \
    log_has esp-core "FAIL Arduino-ESP32 core 3.3.13 differs from the pin 3.3.12"
  show_evidence
}

ac1_unchecked_failure_fails_the_target
arduino_esp32_core_is_the_pin
s390x_percentage_packets_are_compared_with_cortex_m3
ac2_explicit_checks_continue
ac3_passing_target_passes
earlier_failure_marker_does_not_fail_a_rerun
usage_error_exits_2
errexit_ignoring_call_is_refused

if [ "$failures" -ne 0 ]; then
  echo "$failures embedded harness check(s) failed" >&2
  exit 1
fi
echo "embedded harness self-test passed"
