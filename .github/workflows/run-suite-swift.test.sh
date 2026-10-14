#!/usr/bin/env bash
# run-suite.sh swift and swift-min (AZ-2521). Sourced by run-suite.test.sh, which defines bad, $here, $repo and
# $work. `swift` is a fake that logs its arguments, so no toolchain, network or image is used. swift fails without
# Package.swift or swift/, runs the resolve, the strict release build, the verbose tests, the FuzzTests fuzz step (or
# says it is skipped), the thread-sanitizer run, the release speed test and the dependency check in that order, and
# stops at the first failing step; swift-min builds the library only; the wiring rows read the compose files,
# tool-pins.txt, Package.swift and test.yml.

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
    echo 'PackbinTests.GoldenTests/pack_goldenRow()' ;;
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
swscratch="$work/swift-scratch"

run_swift() { # lang tree [VAR=value ...]: runs run-suite.sh <lang> with the fake swift first on PATH
  local lang="$1" tree="$2"
  shift 2
  rm -f "$work/swift.log" "$work/swift.log.env" "$work/swiftresults.rows"
  : > "$work/swift.log"
  env SRC_ROOT="$tree" FIXTURE="${SWIFT_FIXTURE:-$tree/fixtures/golden.hex}" TEST_RESULTS="$work/swiftresults" \
    SWIFT_LOG="$work/swift.log" PACKBIN_SWIFT_SCRATCH="$swscratch" PACKBIN_FUZZ_SECONDS=2 SWIFT_FUZZ_SLEEP=2 \
    PATH="$swbin:$PATH" "$@" \
    perl -e 'alarm 60; exec @ARGV' -- bash "$here/run-suite.sh" "$lang" </dev/null 2>&1
}
sw_row_is() { # lang result: the one report row of the last run
  grep -Eqx "report-row $1 $1 suite [0-9]+ $2" "$work/swiftresults.rows" \
    || bad "$1 report row is not '$2': $(cat "$work/swiftresults.rows" 2>&1)"
  [ "$(wc -l < "$work/swiftresults.rows" | tr -d ' ')" -eq 1 ] || bad "$1: expected exactly one report row: $(cat "$work/swiftresults.rows")"
}
sw_ran() { grep -qF -- "$1" "$work/swift.log"; }

# S1 (AC-3). a tree without Package.swift, or without swift/, fails for swift and swift-min, names what is
# missing, writes one FAIL row and runs no swift
mkdir -p "$work/nomanifest/swift" "$work/nosources" "$work/nomanifest/fixtures" "$work/nosources/fixtures"
for tree in nomanifest nosources; do
  mkdir -p "$work/$tree/.github/workflows"
  cp "$swroot/fixtures/golden.hex" "$work/$tree/fixtures/"
  cp "$swroot/.github/workflows/report-row.sh" "$work/$tree/.github/workflows/"
done
: > "$work/nosources/Package.swift"
for lang in swift swift-min; do
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
done

# S2 (AC-2). every gate in order on a clean tree with a FuzzTests suite; one PASS row
o="--package-path $swroot --scratch-path $swscratch --force-resolved-versions"
out="$(run_swift swift "$swroot" SWIFT_FUZZ=1)"; code=$?
[ "$code" -eq 0 ] || bad "swift: a clean tree failed (exit $code): $out"
sw_row_is swift "PASS "
expected="swift package $o resolve
swift build $o -c release -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
swift build $o --build-tests
swift test $o --skip-build --verbose
swift test list $o --skip-build
swift test $o --skip-build --verbose --filter \\.FuzzTests/
swift build $o --build-tests --sanitize=thread
swift test $o --skip-build --sanitize=thread --verbose
swift build $o -c release --build-tests
swift test $o -c release --skip-build --verbose --filter \\.SpeedTests/ --filter \\.FuzzTests/mebibyte
swift package $o describe --type json
swift package $o dump-package"
[ "$(cat "$work/swift.log")" = "$expected" ] || bad "swift: the steps differ from the expected ones: $(diff <(printf '%s\n' "$expected") "$work/swift.log")"
case "$out" in *"skipped"*) bad "swift: the fuzz skip line shows although FuzzTests exists: $out" ;; esac
[ "$(cat "$work/swift.log.env" 2>&1)" = "fuzz seconds 2" ] || bad "swift: the fuzz run did not get its duration: $(cat "$work/swift.log.env" 2>&1)"
# S2b. CI fuzzes 60 s: the default when PACKBIN_FUZZ_SECONDS is unset, and no compose file sets it
grep -qF 'PACKBIN_FUZZ_SECONDS:-60' "$here/run-suite.sh" || bad "swift: the fuzz step does not default to 60 s"
if grep -qF PACKBIN_FUZZ_SECONDS "$repo/docker-compose.test.yml" "$repo/docker-compose.publish.yml"; then bad "swift: a compose file sets the fuzz duration"; fi
# S2c. without PACKBIN_SWIFT_SCRATCH the build output is the package's own .build
run_swift swift "$swroot" PACKBIN_SWIFT_SCRATCH= >/dev/null
if ! grep -qF -- "--scratch-path $swroot/.build --force-resolved-versions" "$work/swift.log"; then bad "swift: the default scratch path is not $swroot/.build: $(head -n 1 "$work/swift.log")"; fi

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
for lang in swift swift-min; do
  out="$(SWIFT_FIXTURE="$work/swift-bad-golden.hex" run_swift "$lang" "$swroot")"; code=$?
  [ "$code" -ne 0 ] || bad "$lang: a wrong golden row passed"
  [ ! -s "$work/swift.log" ] || bad "$lang: a step ran with a wrong golden row: $(cat "$work/swift.log")"
done

# S9 (AC-4). swift-min resolves and builds the library: no tests, no warnings as errors, no sanitizer; its failure fails
out="$(run_swift swift-min "$swroot")"; code=$?
[ "$code" -eq 0 ] || bad "swift-min: a clean tree failed (exit $code): $out"
sw_row_is swift-min "PASS "
expected="swift package $o resolve
swift build $o"
[ "$(cat "$work/swift.log")" = "$expected" ] || bad "swift-min: the steps differ from the expected ones: $(cat "$work/swift.log")"
for step in resolve min-build; do
  out="$(run_swift swift-min "$swroot" SWIFT_FAIL="$step")"; code=$?
  [ "$code" -ne 0 ] || bad "swift-min: a failing $step passed"
done

# S10 (AC-4). the wiring: each Swift service runs its own suite on the image tool-pins.txt names, swift-min's tag is the
# manifest's swift-tools-version, and the scaffold job runs swift-min after swift
service_line() { # compose file, service, key: the value of "    key:" in that service's block
  awk -v svc="  $2:" -v key="    $3: " '
    $0 == svc { inside = 1; next }
    inside && /^  [^ ]/ { inside = 0 }
    inside && index($0, key) == 1 { print substr($0, length(key) + 1); exit }
  ' "$1"
}
for pair in swift:swift swift-min:swift-min; do
  svc="${pair%%:*}"
  pin="$(bash "$here/tool-pin.sh" "${pair#*:}")" || bad "$svc: tool-pins.txt has no ${pair#*:} pin"
  [ "$(service_line "$repo/docker-compose.test.yml" "$svc" image)" = "swift:$pin" ] \
    || bad "$svc: the compose image is not swift:$pin: $(service_line "$repo/docker-compose.test.yml" "$svc" image)"
  [ "$(service_line "$repo/docker-compose.test.yml" "$svc" command)" = "[\"exec /src/.github/workflows/run-suite.sh $svc\"]" ] \
    || bad "$svc: the compose service does not run run-suite.sh $svc"
done
tools="$(sed -n '1s|^// swift-tools-version: *\([0-9.]*\).*|\1|p' "$repo/Package.swift")"
[ -n "$tools" ] && [ "$(bash "$here/tool-pin.sh" swift-min)" = "$tools" ] \
  || bad "swift-min: the pin $(bash "$here/tool-pin.sh" swift-min) is not the manifest's swift-tools-version '$tools'"
suites="$(sed -n 's/^ *for lang in \(.*\); do$/\1/p' "$here/test.yml" | grep -w swift)"
case " $suites " in *" swift swift-min "*) ;; *) bad "test.yml: the scaffold job does not run swift-min right after swift: '$suites'" ;; esac

# S11. the build output is outside the mounted tree, and the publish file mounts the tree read-only
for svc in swift swift-min; do
  scratch="$(service_line "$repo/docker-compose.test.yml" "$svc" "  PACKBIN_SWIFT_SCRATCH")"
  case "$scratch" in /src | /src/*) bad "$svc: the build output is inside the mounted tree: $scratch" ;; "") bad "$svc: no PACKBIN_SWIFT_SCRATCH" ;; esac
done
ro="$(awk '$0 == "  swift:" { inside = 1; next } inside && /^  [^ ]/ { exit } inside' "$repo/docker-compose.publish.yml")"
grep -qx '      - ./:/src:ro' <<< "$ro" || bad "swift: the publish file does not mount the tree read-only: $ro"
grep -qF 'swift-min:' "$repo/docker-compose.publish.yml" && grep -qF 'volumes: *swift-publish-volumes' "$repo/docker-compose.publish.yml" \
  || bad "swift-min: the publish file does not give it the read-only volumes"
