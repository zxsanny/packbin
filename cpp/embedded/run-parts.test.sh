#!/usr/bin/env bash
# Self-test of the stage parts and the timing notice of cpp/embedded/run.sh (AZ-2607). The host form runs
# against a fake docker that logs its arguments and writes report rows, so no image, toolchain or network
# is used; the in-container forms run against stub target functions. Runs on Linux and on the Mac (a `date`
# shim stands in for the GNU date that lib.sh needs).
#
# PACKBIN_EMBEDDED_UNDER_TEST names another directory with a run.sh and lib.sh (and the stage scripts),
# which is how the mutation proof runs this test against a mutated copy.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
under="${PACKBIN_EMBEDDED_UNDER_TEST:-$here}"

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
failures=0
scenario_failed=0
tree=""
host_rc=0
stage_rc=0
gha_value=""
fake_fail=""
fake_odd=""
esp_part=""

# The targets that must exist, in run order: stage, id, function, part. This is the oracle of the test,
# written down from the run.sh of loop 30 (before AZ-2607); run.sh holds its own table, which `list` prints.
oracle() {
  printf '%s\n' \
    'arm cpp-m0plus target_m0plus -' \
    'arm cpp-m3-qemu target_m3 -' \
    'arm cpp-m4f target_m4f -' \
    'arm cpp-s390x target_s390x -' \
    'arm cpp-avr-uno target_avr_uno -' \
    'esp cpp-esp32s3 target_esp32s3 core' \
    'esp cpp-esp32c3 target_esp32c3 core' \
    'esp cpp-example-esp-idf target_example_esp_idf packages' \
    'esp cpp-example-esp32-arduino target_example_esp32_arduino core' \
    'esp cpp-example-pico target_example_pico packages'
}

# The oracle ids of a stage, and of one ESP part when $2 is given, on one line.
oracle_ids() {
  oracle | awk -v stage="$1" -v part="${2:-}" '$1 == stage && (part == "" || part == "all" || $4 == part) { printf "%s%s", sep, $2; sep = " " }'
}

# `run.sh list ...` of the directory under test, on one line.
listed() {
  bash "$under/run.sh" list "$@" < /dev/null | tr '\n' ' ' | sed 's/ $//'
}

# Fake docker. FAKE_TREE is the temp tree; FAKE_FAIL (build, arm or esp) makes that call fail; FAKE_ODD_IDS=1
# gives the two arm rows an id with a % and an id with a CR.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_TREE/docker.log"
row() {
  SRC_ROOT="$FAKE_TREE" TEST_RESULTS="$FAKE_TREE/test-results" \
    bash "$FAKE_TREE/.github/workflows/report-row.sh" "$1" "fake $1" "$2" "$3" ""
}
status=0
case " $* " in
  *" build "*)
    [ "${FAKE_FAIL:-}" != build ] || exit 3
    ;;
  *" cpp-embedded-esp "*)
    part=unset
    words="$*"
    case " $words " in
      *" PACKBIN_ESP_PART="*)
        part="${words#*PACKBIN_ESP_PART=}"
        part="${part%% *}"
        ;;
    esac
    result=PASS
    if [ "${FAKE_FAIL:-}" = esp ]; then result=FAIL; status=1; fi
    row "fake-esp-$part-1" 46000 PASS
    row "fake-esp-$part-2" 28000 "$result"
    ;;
  *" cpp-embedded "*)
    first=fake-arm-1
    second=fake-arm-2
    if [ "${FAKE_ODD_IDS:-}" = 1 ]; then
      first="odd-100%"
      second=$'odd-cr\rx'
    fi
    result=PASS
    if [ "${FAKE_FAIL:-}" = arm ]; then result=FAIL; status=1; fi
    row "$first" 1500 PASS
    row "$second" 40000 "$result"
    ;;
esac
exit "$status"
EOF
chmod +x "$tmp/bin/docker"

# lib.sh times a target with date +%s%N, which only GNU date has; the shim answers that one call.
case "$(date +%s%N)" in
  *[!0-9]*)
    cat > "$tmp/bin/date" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = +%s%N ]; then
  exec perl -MTime::HiRes=gettimeofday -e '($s, $us) = gettimeofday; printf "%d%06d000\n", $s, $us'
fi
exec /bin/date "$@"
EOF
    chmod +x "$tmp/bin/date"
    ;;
esac

# A temp tree with the run.sh and lib.sh under test, the real report-row.sh and an empty compose file.
new_tree() {
  tree="$tmp/$1"
  mkdir -p "$tree/cpp/embedded" "$tree/.github/workflows"
  cp "$under/run.sh" "$under/lib.sh" "$tree/cpp/embedded/"
  cp "$repo/.github/workflows/report-row.sh" "$tree/.github/workflows/"
  : > "$tree/docker-compose.test.yml"
  gha_value=""
  fake_fail=""
  fake_odd=""
  esp_part=""
}

# Runs `run.sh <args>` of the tree against the fake docker; stdout and stderr go to separate files.
run_host() {
  host_rc=0
  local envs=(-u GITHUB_ACTIONS -u PACKBIN_ESP_PART "PATH=$tmp/bin:$PATH" "FAKE_TREE=$tree"
    "FAKE_FAIL=$fake_fail" "FAKE_ODD_IDS=$fake_odd")
  if [ -n "$gha_value" ]; then envs+=("GITHUB_ACTIONS=$gha_value"); fi
  rm -f "$tree/docker.log"
  env "${envs[@]}" bash "$tree/cpp/embedded/run.sh" "$@" > "$tree/stdout.txt" 2> "$tree/stderr.txt" \
    < /dev/null || host_rc=$?
}

# Runs `run.sh <stage>` inside a stand-in container: stub targets, the part from $esp_part.
run_stage() {
  stage_rc=0
  local envs=(-u GITHUB_ACTIONS -u PACKBIN_ESP_PART "PATH=$tmp/bin:$PATH" "SRC_ROOT=$tree" "TEST_RESULTS=$tree/results")
  if [ -n "$esp_part" ]; then envs+=("PACKBIN_ESP_PART=$esp_part"); fi
  env "${envs[@]}" bash "$tree/cpp/embedded/run.sh" "$@" > "$tree/stage.out" 2>&1 < /dev/null || stage_rc=$?
}

# Stub target functions for every oracle target, in the file of the real script that defines the function.
write_stubs() {
  local fn file
  : > "$tree/cpp/embedded/arm.sh"
  : > "$tree/cpp/embedded/esp.sh"
  : > "$tree/cpp/embedded/examples.sh"
  while read -r _ _ fn _; do
    file="$(grep -l "^$fn()" "$under/arm.sh" "$under/esp.sh" "$under/examples.sh" || true)"
    file="${file%%$'\n'*}"
    [ -n "$file" ] || file="$under/esp.sh"
    printf '%s() { note "ran %s"; }\n' "$fn" "$fn" >> "$tree/cpp/embedded/$(basename "$file")"
  done < <(oracle)
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

check_eq() {
  if [ "$2" = "$3" ]; then
    echo "PASS $1"
  else
    echo "FAIL $1" >&2
    printf '  expected: %s\n  actual:   %s\n' "$2" "$3" >&2
    failures=$((failures + 1))
    scenario_failed=1
  fi
}

show_evidence() {
  if [ "$scenario_failed" -ne 0 ]; then
    sed 's/^/  stdout: /' "$tree/stdout.txt" >&2 || true
    sed 's/^/  stderr: /' "$tree/stderr.txt" >&2 || true
    sed 's/^/  docker: /' "$tree/docker.log" >&2 || true
    scenario_failed=0
  fi
}

docker_calls() {
  if [ -f "$tree/docker.log" ]; then sed "s|$tree|TREE|g" "$tree/docker.log"; fi
}

notice_count() {
  cat "$tree/stdout.txt" "$tree/stderr.txt" | awk '/^::notice/ { n++ } END { print n + 0 }'
}

notice_on_stdout_matches() {
  [ "$(awk '/^::notice/ { n++ } END { print n + 0 }' "$tree/stdout.txt")" -eq 1 ] \
    && grep -E "^::notice " "$tree/stdout.txt" | grep -Eq "$1"
}

rc_is() {
  [ "$host_rc" -eq "$1" ]
}

stderr_names_the_parts() {
  grep -q 'core' "$tree/stderr.txt" && grep -q 'packages' "$tree/stderr.txt" && grep -q 'all' "$tree/stderr.txt"
}

compose="compose -f TREE/docker-compose.test.yml"

targets_are_listed_once_and_match_the_oracle() {
  # Arrange
  local arm all core packages union
  # Act
  arm="$(listed arm)"
  all="$(listed esp)"
  core="$(listed esp core)"
  packages="$(listed esp packages)"
  union="$(printf '%s %s\n' "$core" "$packages" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"
  # Assert
  check_eq "list arm is the arm targets in order" "$(oracle_ids arm)" "$arm"
  check_eq "list esp is the five ESP targets in today's order" "$(oracle_ids esp)" "$all"
  check_eq "list esp all is the same as list esp" "$all" "$(listed esp all)"
  check_eq "list esp core is the core part in order" "$(oracle_ids esp core)" "$core"
  check_eq "list esp packages is the packages part in order" "$(oracle_ids esp packages)" "$packages"
  check_eq "core and packages together are exactly the ESP targets, each once" \
    "$(printf '%s\n' "$all" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')" "$union"
  check_eq "no id is in both parts" "" "$(comm -12 <(printf '%s\n' "$core" | tr ' ' '\n' | sort) <(printf '%s\n' "$packages" | tr ' ' '\n' | sort))"
  check_eq "no id is listed twice across the arm and ESP stages" "" \
    "$(printf '%s %s\n' "$arm" "$all" | tr ' ' '\n' | sort | uniq -d)"
  check_eq "every oracle function is defined by arm.sh, esp.sh or examples.sh" "" \
    "$(oracle | while read -r _ _ fn _; do grep -q "^$fn()" "$under/arm.sh" "$under/esp.sh" "$under/examples.sh" || echo "$fn"; done)"
}

host_forms_call_the_right_compose_commands() {
  local build="$compose build cpp-embedded" arm="$compose run --rm cpp-embedded"
  local esp="$compose run --rm -e PACKBIN_ESP_PART="
  # Arrange / Act / Assert for each form on its own tree
  new_tree host_arm
  run_host host arm
  check_eq "host arm: the image build and the arm stage, nothing else" "$build"$'\n'"$arm" "$(docker_calls)"
  check "host arm exits 0" rc_is 0
  show_evidence

  new_tree host_esp_core
  run_host host esp core
  check_eq "host esp core: one ESP run with PACKBIN_ESP_PART=core, no build" "${esp}core cpp-embedded-esp" "$(docker_calls)"
  check "host esp core exits 0" rc_is 0
  show_evidence

  new_tree host_esp_packages
  run_host host esp packages
  check_eq "host esp packages: one ESP run with PACKBIN_ESP_PART=packages" "${esp}packages cpp-embedded-esp" "$(docker_calls)"
  show_evidence

  new_tree host_esp
  run_host host esp
  check_eq "host esp: one ESP run with PACKBIN_ESP_PART=all" "${esp}all cpp-embedded-esp" "$(docker_calls)"
  show_evidence

  new_tree host_esp_all
  run_host host esp all
  check_eq "host esp all: one ESP run with PACKBIN_ESP_PART=all" "${esp}all cpp-embedded-esp" "$(docker_calls)"
  show_evidence

  new_tree host_host
  run_host host
  check_eq "host: build, arm stage, then the whole ESP stage" "$build"$'\n'"$arm"$'\n'"${esp}all cpp-embedded-esp" "$(docker_calls)"
  show_evidence

  new_tree host_none
  run_host
  check_eq "no argument: the same as host" "$build"$'\n'"$arm"$'\n'"${esp}all cpp-embedded-esp" "$(docker_calls)"
  show_evidence
}

the_notice_is_one_line_per_new_row_and_a_total() {
  local row="PASS%0Aembedded: " total="embedded: total took [0-9]+ s in"
  # Arrange
  new_tree notice_arm
  gha_value=true
  # Act
  run_host host arm
  # Assert
  check "host arm: one notice with both rows (1500 ms is 2 s) and the total" notice_on_stdout_matches \
    "^::notice title=embedded arm timing::embedded: fake-arm-1 took 2 s ${row}fake-arm-2 took 40 s PASS%0A$total 2 targets$"
  check_eq "the notice is on stdout, none on stderr" 0 "$(awk '/^::notice/ { n++ } END { print n + 0 }' "$tree/stderr.txt")"
  show_evidence

  new_tree notice_core
  gha_value=true
  run_host host esp core
  check "host esp core: the title says esp core, one line per row" notice_on_stdout_matches \
    "^::notice title=embedded esp core timing::embedded: fake-esp-core-1 took 46 s ${row}fake-esp-core-2 took 28 s PASS%0A$total 2 targets$"
  show_evidence

  new_tree notice_packages
  gha_value=true
  run_host host esp packages
  check "host esp packages: the title says esp packages" notice_on_stdout_matches \
    "^::notice title=embedded esp packages timing::embedded: fake-esp-packages-1 took 46 s ${row}fake-esp-packages-2 took 28 s PASS%0A$total 2 targets$"
  show_evidence

  new_tree notice_esp
  gha_value=true
  run_host host esp
  check "host esp: the title says esp" notice_on_stdout_matches \
    "^::notice title=embedded esp timing::embedded: fake-esp-all-1 took 46 s ${row}fake-esp-all-2 took 28 s PASS%0A$total 2 targets$"
  show_evidence

  new_tree notice_all
  gha_value=true
  run_host host
  check "host: the title says all, the rows of both stages in order" notice_on_stdout_matches \
    "^::notice title=embedded all timing::embedded: fake-arm-1 took 2 s ${row}fake-arm-2 took 40 s ${row}fake-esp-all-1 took 46 s ${row}fake-esp-all-2 took 28 s PASS%0A$total 4 targets$"
  show_evidence
}

the_notice_also_comes_when_a_stage_fails() {
  local total="embedded: total took [0-9]+ s in"
  # Arrange
  new_tree notice_arm_fails
  gha_value=true
  fake_fail=arm
  # Act
  run_host host
  # Assert
  check "a failing arm stage: the exit status is 1" rc_is 1
  check_eq "a failing arm stage: the ESP stage still ran" 1 "$(docker_calls | grep -c 'cpp-embedded-esp' || true)"
  check "a failing arm stage: one notice, the FAIL row in it" notice_on_stdout_matches \
    "^::notice title=embedded all timing::embedded: fake-arm-1 took 2 s PASS%0Aembedded: fake-arm-2 took 40 s FAIL%0Aembedded: fake-esp-all-1 .*$total 4 targets$"
  show_evidence

  new_tree notice_esp_fails
  gha_value=true
  fake_fail=esp
  run_host host esp packages
  check "a failing ESP part: the exit status is 1" rc_is 1
  check "a failing ESP part: one notice, the FAIL row in it" notice_on_stdout_matches \
    "^::notice title=embedded esp packages timing::embedded: fake-esp-packages-1 took 46 s PASS%0Aembedded: fake-esp-packages-2 took 28 s FAIL%0A$total 2 targets$"
  show_evidence

  new_tree notice_build_fails
  gha_value=true
  fake_fail=build
  run_host host arm
  check "a failing image build: the exit status of the build is kept (3)" rc_is 3
  check_eq "a failing image build: no stage ran" "$compose build cpp-embedded" "$(docker_calls)"
  check "a failing image build: one notice with the total only" notice_on_stdout_matches \
    "^::notice title=embedded arm timing::$total 0 targets$"
  show_evidence
}

the_notice_has_only_the_rows_of_this_run() {
  # Arrange: a report left by an earlier run
  new_tree notice_old_rows
  mkdir -p "$tree/test-results"
  printf '%s\n%s\n%s\n' 'Test ID,Test Name,Execution Time (ms),Result,Error Message' \
    'old-1,old one,5000,PASS,' 'old-2,old two,7000,FAIL,exit 1 (log: x)' > "$tree/test-results/report.csv"
  gha_value=true
  # Act
  run_host host arm
  # Assert
  check "the notice has the two new rows and not the old ones" notice_on_stdout_matches \
    "^::notice title=embedded arm timing::embedded: fake-arm-1 took 2 s PASS%0Aembedded: fake-arm-2 took 40 s PASS%0Aembedded: total took [0-9]+ s in 2 targets$"
  show_evidence
}

the_notice_escapes_percent_and_carriage_return() {
  # Arrange
  new_tree notice_escape
  gha_value=true
  fake_odd=1
  # Act
  run_host host arm
  # Assert
  check "% is %25 and CR is %0D in a row id; the lines are joined by %0A" notice_on_stdout_matches \
    "^::notice title=embedded arm timing::embedded: odd-100%25 took 2 s PASS%0Aembedded: odd-cr%0Dx took 40 s PASS%0Aembedded: total took [0-9]+ s in 2 targets$"
  show_evidence
}

there_is_no_notice_outside_github_actions() {
  local value fail
  for value in "" false 1 TRUE; do
    for fail in "" arm; do
      # Arrange
      new_tree "no_notice_${value:-unset}_${fail:-pass}"
      gha_value="$value"
      fake_fail="$fail"
      # Act
      run_host host arm
      # Assert
      check_eq "GITHUB_ACTIONS='${value}', ${fail:-passing} run: no ::notice anywhere" 0 "$(notice_count)"
      show_evidence
    done
  done
}

usage_errors_exit_2_before_docker_runs() {
  local args
  for args in "host bogus" "host arm core" "host esp bogus" "bogus"; do
    # Arrange
    new_tree "usage_${args// /_}"
    gha_value=true
    # Act
    # shellcheck disable=SC2086  # the words of $args are the arguments
    run_host $args
    # Assert
    check "run.sh $args exits 2" rc_is 2
    check_eq "run.sh $args runs no docker command" "" "$(docker_calls)"
    check_eq "run.sh $args prints no notice" 0 "$(notice_count)"
    show_evidence
  done
  new_tree usage_part_message
  run_host host esp bogus
  check "an unknown host part is named in the message with core, packages and all" stderr_names_the_parts
  show_evidence
  check_eq "list esp bogus exits 2" 2 "$(bash "$under/run.sh" list esp bogus > /dev/null 2>&1 < /dev/null && echo 0 || echo $?)"
}

ids_in_report() {
  awk -F, 'NR > 1 { printf "%s%s", sep, $1; sep = " " }' "$tree/results/report.csv"
}

stage_says() {
  grep -q "$1" "$tree/stage.out"
}

in_container_forms_run_only_their_part() {
  local part
  for part in core packages all; do
    # Arrange
    new_tree "stage_$part"
    write_stubs
    esp_part="$part"
    # Act
    run_stage esp
    # Assert
    check_eq "run.sh esp with PACKBIN_ESP_PART=$part runs that part in order" "$(oracle_ids esp "$part")" "$(ids_in_report)"
    check "run.sh esp with PACKBIN_ESP_PART=$part exits 0" test "$stage_rc" -eq 0
  done

  new_tree stage_unset
  write_stubs
  run_stage esp
  check_eq "run.sh esp with PACKBIN_ESP_PART unset runs all five targets" "$(oracle_ids esp)" "$(ids_in_report)"
  check "the stage line for all names no part" stage_says "^embedded stage esp: 0 target(s) failed$"

  new_tree stage_part_line
  write_stubs
  esp_part=core
  run_stage esp
  check "the stage line of a part names the part" stage_says "^embedded stage esp core: 0 target(s) failed$"

  new_tree stage_arm
  write_stubs
  esp_part=core
  run_stage arm
  check_eq "run.sh arm runs the arm targets only, whatever PACKBIN_ESP_PART says" "$(oracle_ids arm)" "$(ids_in_report)"
  check "the stage line of arm is unchanged" stage_says "^embedded stage arm: 0 target(s) failed$"

  new_tree stage_part_fails
  write_stubs
  printf '%s\n' 'target_example_pico() { false; }' >> "$tree/cpp/embedded/examples.sh"
  esp_part=packages
  run_stage esp
  check "a failing target of a part exits 1" test "$stage_rc" -eq 1
  check "a failing target of a part is a FAIL row" grep -q '^cpp-example-pico,.*,FAIL,' "$tree/results/report.csv"
  check "the stage line counts the failure" stage_says "^embedded stage esp packages: 1 target(s) failed$"

  new_tree stage_unknown_part
  write_stubs
  esp_part=bogus
  run_stage esp
  check "an unknown PACKBIN_ESP_PART exits 2 inside the container" test "$stage_rc" -eq 2
  check "it names core, packages and all" stage_says "core, packages, all"
  check "it ran no target" test ! -e "$tree/results/report.csv"
}

targets_are_listed_once_and_match_the_oracle
host_forms_call_the_right_compose_commands
the_notice_is_one_line_per_new_row_and_a_total
the_notice_also_comes_when_a_stage_fails
the_notice_has_only_the_rows_of_this_run
the_notice_escapes_percent_and_carriage_return
there_is_no_notice_outside_github_actions
usage_errors_exit_2_before_docker_runs
in_container_forms_run_only_their_part

if [ "$failures" -ne 0 ]; then
  echo "$failures embedded run.sh part check(s) failed" >&2
  exit 1
fi
echo "embedded run.sh parts self-test passed"
