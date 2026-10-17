#!/usr/bin/env bash
# run-suite.sh swift (AZ-2521). Sourced by run-suite.test.sh, which defines bad, $here, $repo, $work, $suite_sh
# (the script under test), notice_run and notice_is. `swift` is a fake that logs its arguments, so no toolchain, network or image is used. swift fails without
# Package.swift or swift/, runs the resolve, the strict release build, the verbose tests, the FuzzTests fuzz step (or
# says it is skipped), the thread-sanitizer run, the release speed test and the dependency check in that order, and
# stops at the first failing step; CI runs it as three parts (tests, gates, speed, S2d); the wiring rows read the
# compose files, tool-pins.txt and test.yml.

# shellcheck disable=SC2154
swbin="$work/swiftbin"
mkdir -p "$swbin"
# A fake swift: logs its arguments to $SWIFT_LOG, fails the step named by $SWIFT_FAIL, lists SpeedTests (unless
# $SWIFT_NO_SPEED) and FuzzTests (when $SWIFT_FUZZ), sleeps $SWIFT_FUZZ_SLEEP seconds in the fuzz run, and prints the
# shape of `describe --type json` with the dependencies $SWIFT_DEPS and the module types $SWIFT_TYPES.
cat > "$swbin/swift" <<'SWIFT'
#!/bin/sh
echo "swift $*" >> "$SWIFT_LOG"
args=" $* "
case "$1" in
  package)
    case "$args" in
      *" resolve "*) step=resolve ;;
      *" describe "*) step=describe ;;
      *" dump-package "*) step=dump ;;
      *) step=unknown ;;
    esac ;;
  build)
    case "$args" in
      *" --sanitize=thread "*) step=tsan-build ;;
      *" -c release"*" --build-tests "*) step=speed-build ;;
      *" -c release "*) step=release ;;
      *" --build-tests "*) step=tests-build ;;
      *) step=min-build ;;
    esac ;;
  test)
    case "$args" in
      " test list "*) step=list ;;
      *" --sanitize=thread "*) step=tsan ;;
      *"SpeedTests"*) step=speed ;;
      *"FuzzTests"*) step=fuzz ;;
      *) step=test ;;
    esac ;;
  *) step=unknown ;;
esac
if [ "$step" = unknown ]; then echo "fake swift: unexpected arguments $*" >&2; exit 2; fi
if [ "$step" = "${SWIFT_FAIL:-}" ]; then echo "fake swift: $step failed" >&2; exit 1; fi
case "$step" in
  list)
    if [ -z "${SWIFT_NO_SPEED:-}" ]; then echo 'PackbinTests.SpeedTests/roundTrips(form:)'; fi
    if [ -n "${SWIFT_FUZZ:-}" ]; then echo 'PackbinTests.FuzzTests/unpack_corpusAndRandom()'; fi
    echo 'PackbinTests.GoldenTests/pack_goldenRow()'
    for suite in SessionTests SessionHostileTests ConcurrencyTests; do
      [ "$suite" = "${SWIFT_NO_SUITE:-}" ] || echo "PackbinTests.$suite/case()"
    done ;;
  fuzz)
    echo "fuzz seconds ${PACKBIN_FUZZ_SECONDS:-unset}" >> "$SWIFT_LOG.env"
    sleep "${SWIFT_FUZZ_SLEEP:-0}" ;;
  describe)
    echo '{'
    echo '  "dependencies" : ['
    for dep in ${SWIFT_DEPS-swift-crypto}; do printf '    {\n      "identity" : "%s",\n      "type" : "sourceControl"\n    },\n' "$dep"; done
    echo '  ],'
    echo '  "targets" : ['
    for type in ${SWIFT_TYPES-SwiftTarget SwiftTarget}; do printf '    {\n      "module_type" : "%s",\n      "name" : "T"\n    },\n' "$type"; done
    echo '  ]'
    echo '}' ;;
  dump)
    echo '{ "targets" : [ { "settings" : ['
    if [ -n "${SWIFT_UNSAFE:-}" ]; then echo '  { "kind" : { "unsafeFlags" : { "_0" : [ "-Onone" ] } } }'; fi
    echo '] } ] }' ;;
esac
exit 0
SWIFT
chmod +x "$swbin/swift"

swroot="$work/swiftsrc"
mkdir -p "$swroot/swift/Sources/Packbin" "$swroot/fixtures" "$swroot/.github/workflows"
cp "$repo/fixtures/golden.hex" "$swroot/fixtures/golden.hex"
cp "$work/src/.github/workflows/report-row.sh" "$swroot/.github/workflows/"
: > "$swroot/Package.swift"
mkdir -p "$swroot/swift/Tests/PackbinTests"
printf 'func f() async { await withTaskGroup(of: Int.self) { _ in } }\n' > "$swroot/swift/Tests/PackbinTests/ConcurrencyTests.swift"
swscratch="$work/swift-scratch"

run_swift() { # lang tree [VAR=value ...]: runs run-suite.sh <lang> with the fake swift first on PATH
  local lang="$1" tree="$2"
  shift 2
  rm -f "$work/swift.log" "$work/swift.log.env" "$work/swiftresults.rows"
  : > "$work/swift.log"
  env SRC_ROOT="$tree" FIXTURE="${SWIFT_FIXTURE:-$tree/fixtures/golden.hex}" TEST_RESULTS="$work/swiftresults" \
    SWIFT_LOG="$work/swift.log" PACKBIN_SWIFT_SCRATCH="$swscratch" PACKBIN_FUZZ_SECONDS=2 SWIFT_FUZZ_SLEEP=2 \
    PATH="$swbin:$PATH" "$@" \
    perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" "$lang" </dev/null 2>&1
}
sw_row_is() { # lang result: the one report row of the last run
  grep -Eqx "report-row $1 $1 suite [0-9]+ $2" "$work/swiftresults.rows" \
    || bad "$1 report row is not '$2': $(cat "$work/swiftresults.rows" 2>&1)"
  [ "$(wc -l < "$work/swiftresults.rows" | tr -d ' ')" -eq 1 ] || bad "$1: expected exactly one report row: $(cat "$work/swiftresults.rows")"
}
sw_ran() { grep -qF -- "$1" "$work/swift.log"; }

# S1 (AC-3). a tree without Package.swift, or without swift/, fails, names what is missing, writes one FAIL row
# and runs no swift
mkdir -p "$work/nomanifest/swift" "$work/nosources" "$work/nomanifest/fixtures" "$work/nosources/fixtures"
for tree in nomanifest nosources; do
  mkdir -p "$work/$tree/.github/workflows"
  cp "$swroot/fixtures/golden.hex" "$work/$tree/fixtures/"
  cp "$swroot/.github/workflows/report-row.sh" "$work/$tree/.github/workflows/"
done
: > "$work/nosources/Package.swift"
lang=swift
out="$(run_swift "$lang" "$work/nomanifest")"; code=$?
[ "$code" -ne 0 ] || bad "$lang: a tree without Package.swift passed"
case "$out" in *"$work/nomanifest/Package.swift is missing"*"the $lang suite has nothing to run"*) ;; *) bad "$lang: no message naming the missing Package.swift: $out" ;; esac
sw_row_is "$lang" "FAIL suite failed"
[ ! -s "$work/swift.log" ] || bad "$lang: swift ran without Package.swift: $(cat "$work/swift.log")"
out="$(run_swift "$lang" "$work/nosources")"; code=$?
[ "$code" -ne 0 ] || bad "$lang: a tree without swift/ passed"
case "$out" in *"$work/nosources/swift is missing"*) ;; *) bad "$lang: no message naming the missing swift/: $out" ;; esac
sw_row_is "$lang" "FAIL suite failed"
[ ! -s "$work/swift.log" ] || bad "$lang: swift ran without swift/: $(cat "$work/swift.log")"

# S2 (AC-2). every gate in order on a clean tree with a FuzzTests suite; one PASS row
o="--package-path $swroot --scratch-path $swscratch --force-resolved-versions"
c_resolve="swift package $o resolve"
c_release="swift build $o -c release -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete"
c_debug="swift build $o --build-tests"
c_test="swift test $o --skip-build --verbose"
c_list="swift test list $o --skip-build"
c_fuzz="swift test $o --skip-build --verbose --filter \\.FuzzTests/"
c_tsan_build="swift build $o --build-tests --sanitize=thread"
c_tsan="swift test $o --skip-build --sanitize=thread --verbose --filter \\.ConcurrencyTests/ --filter \\.SessionTests/ --filter \\.SessionHostileTests/"
c_speed_build="swift build $o -c release --build-tests"
c_speed_list="swift test list $o -c release --skip-build"
c_speed="swift test $o -c release --skip-build --verbose --filter \\.SpeedTests/ --filter \\.FuzzTests/mebibyte"
c_describe="swift package $o describe --type json"
c_dump="swift package $o dump-package"
out="$(run_swift swift "$swroot" SWIFT_FUZZ=1)"; code=$?
[ "$code" -eq 0 ] || bad "swift: a clean tree failed (exit $code): $out"
sw_row_is swift "PASS "
case "$out" in *"run-suite: swift step took "*" s: swift_resolve"*) ;; *) bad "swift: no step timing line in the output: $out" ;; esac
expected="$(printf '%s\n' "$c_resolve" "$c_release" "$c_debug" "$c_test" "$c_list" "$c_fuzz" "$c_tsan_build" "$c_tsan" "$c_speed_build" "$c_speed" "$c_describe" "$c_dump")"
[ "$(cat "$work/swift.log")" = "$expected" ] || bad "swift: the steps differ from the expected ones: $(diff <(printf '%s\n' "$expected") "$work/swift.log")"
cp "$work/swift.log" "$work/swift.all.log"
case "$out" in *"skipped"*) bad "swift: the fuzz skip line shows although FuzzTests exists: $out" ;; esac
[ "$(cat "$work/swift.log.env" 2>&1)" = "fuzz seconds 2" ] || bad "swift: the fuzz run did not get its duration: $(cat "$work/swift.log.env" 2>&1)"
# S2b. CI fuzzes 60 s: the default when PACKBIN_FUZZ_SECONDS is unset, and no compose file sets it
grep -qF 'PACKBIN_FUZZ_SECONDS:-60' "$suite_sh" || bad "swift: the fuzz step does not default to 60 s"
if grep -qF PACKBIN_FUZZ_SECONDS "$repo/docker-compose.test.yml" "$repo/docker-compose.publish.yml"; then bad "swift: a compose file sets the fuzz duration"; fi
# S2c. without PACKBIN_SWIFT_SCRATCH the build output is the package's own .build
run_swift swift "$swroot" PACKBIN_SWIFT_SCRATCH= >/dev/null
if ! grep -qF -- "--scratch-path $swroot/.build --force-resolved-versions" "$work/swift.log"; then bad "swift: the default scratch path is not $swroot/.build: $(head -n 1 "$work/swift.log")"; fi

# S2d (AZ-2600, AZ-2607). CI runs the suite as three jobs (PACKBIN_SWIFT_PART tests, gates and speed): each part runs
# exactly the commands listed here, in this order (the single run's order, except that the gates part lists the tests
# after its sanitizer build); no command is in two parts but the resolve and the list of the debug build; the three
# parts together run the commands of the single run plus the speed part's own list of its release build; every part
# stops at its first failing step
sw_part_steps() { # part command...: the part passes on a clean tree with a FuzzTests suite and runs exactly these commands
  local part="$1" out code expected
  shift
  expected="$(printf '%s\n' "$@")"
  out="$(run_swift swift "$swroot" SWIFT_FUZZ=1 PACKBIN_SWIFT_PART="$part")"; code=$?
  [ "$code" -eq 0 ] || bad "swift: the $part part failed on a clean tree (exit $code): $out"
  sw_row_is swift "PASS "
  [ "$(cat "$work/swift.log")" = "$expected" ] || bad "swift: the $part part steps differ: $(diff <(printf '%s\n' "$expected") "$work/swift.log")"
  cp "$work/swift.log" "$work/swift.$part.log"
}
sw_part_stops() { # part step...: with each fake step failing in turn (one per command, in order), the part fails and runs nothing after it
  local part="$1" step n=0 code
  shift
  for step in "$@"; do
    n=$((n + 1))
    run_swift swift "$swroot" SWIFT_FUZZ=1 PACKBIN_SWIFT_PART="$part" SWIFT_FAIL="$step" >/dev/null; code=$?
    [ "$code" -ne 0 ] || bad "swift: the $part part passed after a failing $step"
    sw_row_is swift "FAIL $(if [ "$step" = resolve ]; then echo swift dependency resolve failed; else echo suite failed; fi)"
    [ "$(wc -l < "$work/swift.log" | tr -d ' ')" -eq "$n" ] || bad "swift: the $part part did not stop at its command $n ($step): $(cat "$work/swift.log")"
  done
}
sw_part_steps tests "$c_resolve" "$c_debug" "$c_test" "$c_list" "$c_fuzz"
sw_part_steps gates "$c_resolve" "$c_release" "$c_tsan_build" "$c_list" "$c_tsan" "$c_describe" "$c_dump"
sw_part_steps speed "$c_resolve" "$c_speed_build" "$c_speed_list" "$c_speed"
sw_part_stops tests resolve tests-build test list fuzz
sw_part_stops gates resolve release tsan-build list tsan describe dump
sw_part_stops speed resolve speed-build list speed
# Two parts share only the resolve and the list of the debug build; the speed part's list of its release build is its own
shared="$(cat "$work/swift.tests.log" "$work/swift.gates.log" "$work/swift.speed.log" | sort | uniq -d)"
[ "$shared" = "$(printf '%s\n%s\n' "$c_list" "$c_resolve" | sort)" ] || bad "swift: the parts share more than the resolve and the list: $shared"
cat "$work/swift.tests.log" "$work/swift.gates.log" "$work/swift.speed.log" | sort -u | grep -vxF "$c_speed_list" > "$work/swift.parts.sorted"
sort -u "$work/swift.all.log" > "$work/swift.all.sorted"
cmp -s "$work/swift.all.sorted" "$work/swift.parts.sorted" || bad "swift: the three parts do not run the commands of the single run: $(diff "$work/swift.all.sorted" "$work/swift.parts.sorted")"
# the single run without a part, and with an empty one, is the all run
run_swift swift "$swroot" SWIFT_FUZZ=1 >/dev/null
cmp -s "$work/swift.all.log" "$work/swift.log" || bad "swift: a run without PACKBIN_SWIFT_PART differs from the all run: $(diff "$work/swift.all.log" "$work/swift.log")"
run_swift swift "$swroot" SWIFT_FUZZ=1 PACKBIN_SWIFT_PART= >/dev/null
cmp -s "$work/swift.all.log" "$work/swift.log" || bad "swift: an empty PACKBIN_SWIFT_PART differs from the all run: $(diff "$work/swift.all.log" "$work/swift.log")"
# a part the suite does not know fails by name before any step
out="$(run_swift swift "$swroot" PACKBIN_SWIFT_PART=all-of-it)"; code=$?
[ "$code" -ne 0 ] || bad "swift: an unknown part passed"
case "$out" in *"PACKBIN_SWIFT_PART is all-of-it, not all, tests, gates or speed"*) ;; *) bad "swift: no message for an unknown part: $out" ;; esac
sw_row_is swift "FAIL suite failed"
[ ! -s "$work/swift.log" ] || bad "swift: a step ran for an unknown part: $(cat "$work/swift.log")"
# the gates part keeps its guards: a missing sanitizer suite fails it by name
out="$(run_swift swift "$swroot" PACKBIN_SWIFT_PART=gates SWIFT_NO_SUITE=SessionTests)"; code=$?
[ "$code" -ne 0 ] || bad "swift: the gates part passed without SessionTests"
case "$out" in *"no SessionTests suite"*) ;; *) bad "swift: the gates part has no message for the missing SessionTests suite: $out" ;; esac
# the speed part lists its own release build, so a package without SpeedTests still fails it by name (S6), and the
# SpeedTests suite is not a gates or tests part business
out="$(run_swift swift "$swroot" PACKBIN_SWIFT_PART=speed SWIFT_NO_SPEED=1)"; code=$?
[ "$code" -ne 0 ] || bad "swift: the speed part passed without SpeedTests"
case "$out" in *"swift has no SpeedTests suite; the release-build speed step has nothing to run"*) ;; *) bad "swift: the speed part has no message for the missing SpeedTests suite: $out" ;; esac
sw_row_is swift "FAIL suite failed"
if sw_ran "--filter \\.SpeedTests/"; then bad "swift: the speed part ran the speed tests without a SpeedTests suite: $(cat "$work/swift.log")"; fi
for part in tests gates; do
  run_swift swift "$swroot" PACKBIN_SWIFT_PART="$part" SWIFT_NO_SPEED=1 >/dev/null; code=$?
  [ "$code" -eq 0 ] || bad "swift: the $part part needs a SpeedTests suite (exit $code)"
done
# a release list that fails is the failure of that step, not a package without SpeedTests
out="$(run_swift swift "$swroot" PACKBIN_SWIFT_PART=speed SWIFT_FAIL=list)"; code=$?
[ "$code" -ne 0 ] || bad "swift: the speed part passed after a failed release list"
case "$out" in *"no SpeedTests suite"*) bad "swift: a failed release list is reported as a missing SpeedTests suite: $out" ;; esac

# S2e (AZ-2607 AC-2). on GitHub Actions each part writes one notice titled with the part, over its own steps (the
# numbers the parts are balanced from; the speed part's 2 steps are the resolve and the whole speed step); the single
# run's title has no part; a failed step keeps the notice; a part name is escaped as a property value (notice_run and
# notice_is: run-suite.test.sh)
sw_notice() { # [VAR=value ...]
  notice_run swift "$swroot" PATH="$swbin:$PATH" SWIFT_LOG="$work/swift.log" PACKBIN_SWIFT_SCRATCH="$swscratch" GITHUB_ACTIONS=true "$@"
}
# Act and assert
sw_notice PACKBIN_SWIFT_PART=tests
notice_is "swift (tests) suite timing" swift 5
sw_notice PACKBIN_SWIFT_PART=gates
notice_is "swift (gates) suite timing" swift 6
sw_notice PACKBIN_SWIFT_PART=speed
notice_is "swift (speed) suite timing" swift 2
sw_notice
notice_is "swift suite timing" swift 10
# the labels drop swift_opts, so the 110-character cut leaves the options that tell the four builds apart
labels="$(sed -n 's/^run-suite: swift step took [0-9]* s: //p' "$work/notice.err")"
if grep -qF -- '--package-path' <<< "$labels"; then bad "swift: a step label keeps the swift options: $labels"; fi
[ -z "$(sort <<< "$labels" | uniq -d)" ] || bad "swift: two steps have the same label: $(sort <<< "$labels" | uniq -d)"
grep -qx 'swift build --build-tests --sanitize=thread' <<< "$labels" || bad "swift: no label for the sanitizer build: $labels"
sw_notice PACKBIN_SWIFT_PART=all
notice_is "swift suite timing" swift 10
sw_notice PACKBIN_SWIFT_PART=gates SWIFT_FAIL=tsan-build
notice_is "swift (gates) suite timing" swift 3
sw_notice PACKBIN_SWIFT_PART=speed SWIFT_FAIL=list
notice_is "swift (speed) suite timing" swift 2
sw_notice PACKBIN_SWIFT_PART=a:b,c
notice_is "swift (a%3Ab%2Cc) suite timing" swift 0

# S3. no FuzzTests suite yet: the step says it is skipped and does not fuzz
out="$(run_swift swift "$swroot")"; code=$?
[ "$code" -eq 0 ] || bad "swift: a tree without a fuzz suite failed (exit $code): $out"
case "$out" in *"fuzz step skipped"*"no FuzzTests suite"*) ;; *) bad "swift: no skip line without a fuzz suite: $out" ;; esac
if sw_ran "--filter \\.FuzzTests/ " || grep -qE -- "--filter \\\\\.FuzzTests/$" "$work/swift.log"; then bad "swift: fuzzed without a FuzzTests suite"; fi

# S4. a fuzz run shorter than asked fails (a suite that ignores PACKBIN_FUZZ_SECONDS) and stops the later steps
out="$(run_swift swift "$swroot" SWIFT_FUZZ=1 SWIFT_FUZZ_SLEEP=0)"; code=$?
[ "$code" -ne 0 ] || bad "swift: a fuzz run under the asked duration passed"
case "$out" in *"under the 2 s asked for"*) ;; *) bad "swift: no message for a short fuzz run: $out" ;; esac
if sw_ran "--sanitize=thread"; then bad "swift: the sanitizer ran after the fuzz step failed"; fi

# S5. each failing step fails the run, writes a FAIL row and stops the later steps; a failed resolve says so
for step in resolve release tests-build test list fuzz tsan-build tsan speed-build speed describe dump; do
  # Only the fuzz row lists FuzzTests: a listed suite costs the fake 2 s in every later step.
  fuzz=; [ "$step" != fuzz ] || fuzz=1
  out="$(run_swift swift "$swroot" SWIFT_FUZZ="$fuzz" SWIFT_FAIL="$step")"; code=$?
  [ "$code" -ne 0 ] || bad "swift: a failing $step passed"
  if [ "$step" = resolve ]; then sw_row_is swift "FAIL swift dependency resolve failed"; else sw_row_is swift "FAIL suite failed"; fi
done
run_swift swift "$swroot" SWIFT_FAIL=resolve >/dev/null
if sw_ran " build "; then bad "swift: built after the resolve failed"; fi
run_swift swift "$swroot" SWIFT_FAIL=release >/dev/null
if sw_ran "--build-tests"; then bad "swift: the tests were built after the release build failed"; fi
run_swift swift "$swroot" SWIFT_FAIL=test >/dev/null
if sw_ran "--sanitize=thread"; then bad "swift: the sanitizer ran after the tests failed"; fi

# S6. no SpeedTests suite: the speed step fails by name instead of passing on a filter that matches nothing
out="$(run_swift swift "$swroot" SWIFT_NO_SPEED=1)"; code=$?
[ "$code" -ne 0 ] || bad "swift: a tree without SpeedTests passed"
case "$out" in *"no SpeedTests suite"*) ;; *) bad "swift: no message for the missing SpeedTests suite: $out" ;; esac
if sw_ran "-c release --build-tests"; then bad "swift: the speed build ran without a SpeedTests suite"; fi
# the speed part has no list before its build, so it builds, lists the release build and then fails by the same name
out="$(run_swift swift "$swroot" PACKBIN_SWIFT_PART=speed SWIFT_NO_SPEED=1)"; code=$?
[ "$code" -ne 0 ] || bad "swift: the speed part of a tree without SpeedTests passed"
case "$out" in *"no SpeedTests suite"*) ;; *) bad "swift: no message for the missing SpeedTests suite in the speed part: $out" ;; esac
sw_ran "-c release --skip-build" || bad "swift: the speed part did not list its release build: $(cat "$work/swift.log")"

# S6b. a suite of the thread-sanitizer run is gone from the list: the step fails by name, the filter never runs
for suite in SessionTests SessionHostileTests ConcurrencyTests; do
  out="$(run_swift swift "$swroot" SWIFT_NO_SUITE="$suite")"; code=$?
  [ "$code" -ne 0 ] || bad "swift: a tree without $suite passed"
  case "$out" in *"no $suite suite"*) ;; *) bad "swift: no message for the missing $suite suite: $out" ;; esac
  if sw_ran "--sanitize=thread --verbose"; then bad "swift: the sanitized tests ran without a $suite suite"; fi
done

# S6c. a test file that uses threads outside the sanitized suites fails by name; the allowed file passes (S2)
printf 'func f() async { await withTaskGroup(of: Int.self) { _ in } }\n' > "$swroot/swift/Tests/PackbinTests/RaceTests.swift"
out="$(run_swift swift "$swroot")"; code=$?
rm -f "$swroot/swift/Tests/PackbinTests/RaceTests.swift"
[ "$code" -ne 0 ] || bad "swift: a threaded test file outside the sanitized suites passed"
case "$out" in *"use threads outside"*"RaceTests.swift"*) ;; *) bad "swift: the threaded file is not named: $out" ;; esac
if sw_ran "--sanitize=thread --verbose"; then bad "swift: the sanitized tests ran with a threaded file outside the suites"; fi

# S7 (SW-11). a second package, a target that is not Swift, an unsafe flag or an unreadable describe fails and is
# named; swift-crypto alone (S2) passes and no dependency fails (SW-11 asks for exactly one)
out="$(run_swift swift "$swroot" SWIFT_DEPS="swift-crypto swift-collections")"; code=$?
[ "$code" -ne 0 ] || bad "swift: a second package dependency passed"
case "$out" in *"other than swift-crypto"*"swift-collections"*) ;; *) bad "swift: the extra package is not named: $out" ;; esac
out="$(run_swift swift "$swroot" SWIFT_DEPS=)"; code=$?
[ "$code" -ne 0 ] || bad "swift: a package without swift-crypto passed"
case "$out" in *"does not depend on swift-crypto"*) ;; *) bad "swift: no message for the missing swift-crypto: $out" ;; esac
out="$(run_swift swift "$swroot" SWIFT_TYPES="SwiftTarget ClangTarget")"; code=$?
[ "$code" -ne 0 ] || bad "swift: a C target passed"
case "$out" in *"not Swift targets"*"ClangTarget"*) ;; *) bad "swift: the C target is not named: $out" ;; esac
out="$(run_swift swift "$swroot" SWIFT_UNSAFE=1)"; code=$?
[ "$code" -ne 0 ] || bad "swift: an unsafe flag passed"
case "$out" in *"unsafe flags"*) ;; *) bad "swift: no message for the unsafe flag: $out" ;; esac
out="$(run_swift swift "$swroot" SWIFT_TYPES=)"; code=$?
[ "$code" -ne 0 ] || bad "swift: a describe output without targets passed"
case "$out" in *"lists no targets"*) ;; *) bad "swift: no message for a describe output without targets: $out" ;; esac

# S8. a fixture without the golden row fails before any swift step
printf '00\n' > "$work/swift-bad-golden.hex"
lang=swift
out="$(SWIFT_FIXTURE="$work/swift-bad-golden.hex" run_swift "$lang" "$swroot")"; code=$?
[ "$code" -ne 0 ] || bad "$lang: a wrong golden row passed"
[ ! -s "$work/swift.log" ] || bad "$lang: a step ran with a wrong golden row: $(cat "$work/swift.log")"

# S10 (AC-4). the wiring: the Swift service runs its own suite on the image tool-pins.txt names, and the scaffold job
# runs it
service_line() { # compose file, service, key: the value of "    key:" in that service's block
  awk -v svc="  $2:" -v key="    $3: " '
    $0 == svc { inside = 1; next }
    inside && /^  [^ ]/ { inside = 0 }
    inside && index($0, key) == 1 { print substr($0, length(key) + 1); exit }
  ' "$1"
}
svc=swift
pin="$(bash "$here/tool-pin.sh" "$svc")" || bad "$svc: tool-pins.txt has no $svc pin"
[ "$(service_line "$repo/docker-compose.test.yml" "$svc" image)" = "swift:$pin" ] \
  || bad "$svc: the compose image is not swift:$pin: $(service_line "$repo/docker-compose.test.yml" "$svc" image)"
[ "$(service_line "$repo/docker-compose.test.yml" "$svc" command)" = "[\"exec /src/.github/workflows/run-suite.sh $svc\"]" ] \
  || bad "$svc: the compose service does not run run-suite.sh $svc"
# AZ-2600, AZ-2607: the suites job is a matrix; its three swift entries run the three parts, no entry runs the whole suite
swift_entries="$(ruby -ryaml -e 'inc = YAML.safe_load(File.read(ARGV[0]))["jobs"]["suites"]["strategy"]["matrix"]["include"]; puts inc.select { |e| e["lang"] == "swift" }.map { |e| e["part"].to_s }.sort.join(" ")' "$here/test.yml")"
[ "$swift_entries" = "gates speed tests" ] || bad "test.yml: the suites matrix does not run the swift parts tests, gates and speed once each: '$swift_entries'"

# S11. the build output is outside the mounted tree, and the publish file mounts the tree read-only
svc=swift
scratch="$(service_line "$repo/docker-compose.test.yml" "$svc" "  PACKBIN_SWIFT_SCRATCH")"
case "$scratch" in /src | /src/*) bad "$svc: the build output is inside the mounted tree: $scratch" ;; "") bad "$svc: no PACKBIN_SWIFT_SCRATCH" ;; esac
ro="$(awk '$0 == "  swift:" { inside = 1; next } inside && /^  [^ ]/ { exit } inside' "$repo/docker-compose.publish.yml")"
grep -qx '      - ./:/src:ro' <<< "$ro" || bad "swift: the publish file does not mount the tree read-only: $ro"
