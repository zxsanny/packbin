#!/usr/bin/env bash
# run-suite.sh dart (AZ-4145). Sourced by run-suite.test.sh, which defines bad, $here, $repo, $work and $suite_sh (the
# script under test); it also runs on its own (`bash run-suite-dart.test.sh`). `dart` is a fake that logs its arguments,
# so no SDK, network or image is used. The suite fails without dart/pubspec.yaml, checks the dependencies and the
# imports first, then runs pub get, format, analyze, the verbose tests, the seeded unpack run (or says it is not
# present), and the speed program compiled to an executable, in that order, and stops at the first failing step. The
# wiring rows read the compose file, tool-pins.txt and test.yml. The last rows run the real steps on a temporary package
# when a real `dart` is on PATH (the Mac); without one they say they are skipped.

# shellcheck disable=SC2154
if ! declare -F bad > /dev/null; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo="$(cd "$here/../.." && pwd)"
  suite_sh="$here/run-suite.sh"
  work="$(mktemp -d "${TMPDIR:-/tmp}/run-suite-dart-test.XXXXXX")"
  trap 'rm -rf "$work"' EXIT
  fail=0
  bad() { echo "FAIL: $1"; fail=1; }
  unset GITHUB_ACTIONS
  dart_alone=1
fi

dbin="$work/dartbin"
mkdir -p "$dbin"
# A fake dart: logs its arguments to $DART_LOG, fails the step named by $DART_FAIL (pub, format, analyze, test, seeded,
# compile), makes `compile exe ... -o OUT` write an executable that logs "speed-exe" and fails when $DART_FAIL is
# speed, and sleeps $DART_FUZZ_SLEEP seconds in the seeded run. It refuses a test run without `-r expanded`.
cat > "$dbin/dart" <<'DART'
#!/bin/sh
echo "dart $*" >> "$DART_LOG"
args=" $* "
case "$1" in
  pub) step=pub ;;
  format) step=format ;;
  analyze) step=analyze ;;
  test)
    case "$args" in *" -r expanded "*) ;; *) echo "fake dart: a test run without -r expanded: $*" >&2; exit 2 ;; esac
    case "$args" in *seeded_run_test*) step=seeded ;; *) step=test ;; esac ;;
  compile) step=compile ;;
  *) echo "fake dart: unexpected arguments $*" >&2; exit 2 ;;
esac
if [ "$step" = "${DART_FAIL:-}" ]; then echo "fake dart: $step failed" >&2; exit 1; fi
case "$step" in
  seeded)
    echo "fuzz seconds ${PACKBIN_FUZZ_SECONDS:-unset}" >> "$DART_LOG"
    sleep "${DART_FUZZ_SLEEP:-0}" ;;
  compile)
    out=
    while [ $# -gt 0 ]; do if [ "$1" = -o ]; then out="$2"; fi; shift; done
    printf '#!/bin/sh\necho speed-exe >> "%s"\n[ "${DART_FAIL:-}" != speed ] || exit 1\n' "$DART_LOG" > "$out"
    chmod +x "$out" ;;
esac
exit 0
DART
chmod +x "$dbin/dart"

dsroot="$work/dartsrc"
mkdir -p "$dsroot/dart/lib/src" "$dsroot/dart/test/core" "$dsroot/dart/tool" "$dsroot/fixtures" "$dsroot/.github/workflows"
cp "$repo/fixtures/golden.hex" "$dsroot/fixtures/golden.hex"
cat > "$dsroot/.github/workflows/report-row.sh" <<'ROW'
#!/usr/bin/env bash
echo "report-row $*" >> "${TEST_RESULTS}.rows"
ROW
cp "$here/run-suite-dart.sh" "$dsroot/.github/workflows/"
good_pubspec() {
  printf 'name: packbin\nenvironment:\n  sdk: ^3.13.0\ndev_dependencies:\n  lints: ^6.1.0\n  test: ^1.33.0\n' > "$dsroot/dart/pubspec.yaml"
}
good_pubspec
printf "import 'dart:typed_data';\n// dart:io is named here in a comment only\nvoid f() {}\n" > "$dsroot/dart/lib/packbin.dart"
: > "$dsroot/dart/tool/speed.dart"

run_dart() { # tree [VAR=value ...]: runs `run-suite.sh dart` on tree with the fake dart first on PATH
  local tree="$1"
  shift
  rm -f "$work/dart.log" "$work/dartresults.rows"
  : > "$work/dart.log"
  env SRC_ROOT="$tree" FIXTURE="$tree/fixtures/golden.hex" TEST_RESULTS="$work/dartresults" DART_LOG="$work/dart.log" \
    PACKBIN_FUZZ_SECONDS=2 DART_FUZZ_SLEEP=2 PATH="$dbin:$PATH" "$@" \
    perl -e 'alarm 60; exec @ARGV' -- bash "$dsroot/.github/workflows/run-suite.sh" dart </dev/null 2>&1
}
cp "$suite_sh" "$dsroot/.github/workflows/run-suite.sh"
dart_row_is() { # result: the one report row of the last run
  grep -Eqx "report-row dart dart suite [0-9]+ $1 *" "$work/dartresults.rows" \
    || bad "dart report row is not '$1': $(cat "$work/dartresults.rows" 2>&1)"
  [ "$(wc -l < "$work/dartresults.rows" | tr -d ' ')" -eq 1 ] || bad "dart: expected exactly one report row: $(cat "$work/dartresults.rows")"
}
dart_log_steps() { sed -e '/^dart /!d' -e 's/^dart //' "$work/dart.log" | paste -sd '|' -; }

# D1 (AC-1). a good tree: every step runs once, in order, the tests with the verbose reporter, the seeded run says it is
# not present, one PASS row
out="$(run_dart "$dsroot")"; code=$?
[ "$code" -eq 0 ] || bad "dart: a good tree failed (exit $code): $out"
want='pub get|format --output=none --set-exit-if-changed .|analyze --fatal-infos|test -r expanded|compile exe tool/speed.dart -o'
case "$(dart_log_steps)" in "$want"*) ;; *) bad "dart: the steps are not [$want ...]: $(dart_log_steps)" ;; esac
[ "$(grep -c '^speed-exe$' "$work/dart.log")" -eq 1 ] || bad "dart: the compiled speed program did not run once: $(cat "$work/dart.log")"
case "$out" in *"dart seeded unpack run: not present"*) ;; *) bad "dart: no 'not present' line for the seeded run: $out" ;; esac
if grep -q 'seeded_run_test' "$work/dart.log"; then bad "dart: the seeded run started without its test file: $(cat "$work/dart.log")"; fi
if grep -qE ' (-r|--reporter)[ =](compact|silent|json)| -q' "$work/dart.log"; then bad "dart: a quiet or compact reporter was used: $(cat "$work/dart.log")"; fi
dart_row_is "PASS"
[ "$(grep -c '^run-suite: dart step took ' <<< "$out")" -eq 7 ] || bad "dart: expected 7 step lines (deps, pub get, format, analyze, test, seeded, speed): $out"

# D2 (AC-2). a failing step fails the suite and writes a FAIL row; no later step runs (a failing test, an unformatted file
# and an analyzer info are the exit codes of dart test, dart format and dart analyze; the real runs are the last rows)
for fake in pub format analyze test compile speed; do
  out="$(run_dart "$dsroot" DART_FAIL="$fake")"; code=$?
  [ "$code" -ne 0 ] || bad "dart: a failing $fake passed"
  dart_row_is "FAIL suite failed"
  case "$fake" in
    pub) tail_is="dart pub get" ;;
    format) tail_is="dart format --output=none --set-exit-if-changed ." ;;
    analyze) tail_is="dart analyze --fatal-infos" ;;
    test) tail_is="dart test -r expanded" ;;
    compile) tail_is="dart compile exe tool/speed.dart -o" ;;
    speed) tail_is="speed-exe" ;;
  esac
  case "$(tail -n 1 "$work/dart.log")" in "$tail_is"*) ;; *) bad "dart: a step ran after the failing $fake: $(cat "$work/dart.log")" ;; esac
done

# D3. a tree without dart/pubspec.yaml fails, names it, writes one FAIL row and runs no dart
mkdir -p "$work/dartempty/fixtures" "$work/dartempty/.github/workflows"
cp "$dsroot/fixtures/golden.hex" "$work/dartempty/fixtures/"
cp "$dsroot/.github/workflows/report-row.sh" "$work/dartempty/.github/workflows/"
out="$(run_dart "$work/dartempty")"; code=$?
[ "$code" -ne 0 ] || bad "dart: a tree without pubspec.yaml passed"
case "$out" in *"$work/dartempty/dart/pubspec.yaml is missing"*"the dart suite has nothing to run"*) ;; *) bad "dart: no message naming the missing pubspec.yaml: $out" ;; esac
dart_row_is "FAIL suite failed"
[ ! -s "$work/dart.log" ] || bad "dart: dart ran without pubspec.yaml: $(cat "$work/dart.log")"

# D4 (DT-5). the seeded run: once dart/test/limits/seeded_run_test.dart exists it runs for PACKBIN_FUZZ_SECONDS (60 when
# unset), a failing run fails, and a run shorter than asked fails (a test that ignored the duration)
mkdir -p "$dsroot/dart/test/limits"
: > "$dsroot/dart/test/limits/seeded_run_test.dart"
out="$(run_dart "$dsroot")"; code=$?
[ "$code" -eq 0 ] || bad "dart: a tree with the seeded run failed (exit $code): $out"
grep -qx 'dart test -r expanded test/limits/seeded_run_test.dart' "$work/dart.log" || bad "dart: the seeded run did not start: $(cat "$work/dart.log")"
grep -qx 'fuzz seconds 2' "$work/dart.log" || bad "dart: the seeded run did not get its duration: $(cat "$work/dart.log")"
case "$out" in *"not present"*) bad "dart: 'not present' printed although the seeded test exists: $out" ;; esac
out="$(run_dart "$dsroot" DART_FAIL=seeded)"; code=$?
[ "$code" -ne 0 ] || bad "dart: a failing seeded run passed"
if grep -q 'compile exe' "$work/dart.log"; then bad "dart: the speed step ran after a failing seeded run"; fi
out="$(run_dart "$dsroot" DART_FUZZ_SLEEP=0)"; code=$?
[ "$code" -ne 0 ] || bad "dart: a seeded run shorter than asked passed"
case "$out" in *"seeded unpack run took "*"under the 2 s asked for"*) ;; *) bad "dart: no message for the short seeded run: $out" ;; esac
out="$(run_dart "$dsroot" PACKBIN_FUZZ_SECONDS=)"; code=$?
grep -qx 'fuzz seconds 60' "$work/dart.log" || bad "dart: the seeded run is not 60 s when PACKBIN_FUZZ_SECONDS is empty: $(cat "$work/dart.log")"
rm -rf "$dsroot/dart/test/limits"

# D5 (DT-11). a runtime dependency, another development dependency, and an import of dart:io, dart:ffi or dart:mirrors
# under lib/ each fail the suite by name before any dart command runs; an import of another dart: library and a comment
# naming dart:io pass (D1)
deps_fails() { # label needle: the suite failed with the needle in its output, a FAIL row, and no dart command
  local label="$1" needle="$2" got
  got="$(run_dart "$dsroot")"; code=$?
  [ "$code" -ne 0 ] || bad "dart: $label passed"
  case "$got" in *"$needle"*) ;; *) bad "dart: $label: the message does not say [$needle]: $got" ;; esac
  dart_row_is "FAIL suite failed"
  [ ! -s "$work/dart.log" ] || bad "dart: $label: dart ran before the check: $(cat "$work/dart.log")"
}
printf 'name: packbin\nenvironment:\n  sdk: ^3.13.0\ndependencies:\n  crypto: ^3.0.0\ndev_dependencies:\n  test: ^1.33.0\n' > "$dsroot/dart/pubspec.yaml"
deps_fails "a runtime dependency" "no runtime dependency"
printf 'name: packbin\nenvironment:\n  sdk: ^3.13.0\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$dsroot/dart/pubspec.yaml"
deps_fails "a dependencies section naming only the sdk" "no runtime dependency"
printf 'name: packbin\nenvironment:\n  sdk: ^3.13.0\ndependency_overrides:\n  test: any\n' > "$dsroot/dart/pubspec.yaml"
deps_fails "dependency_overrides" "dependency_overrides"
printf 'name: packbin\nenvironment:\n  sdk: ^3.13.0\ndev_dependencies:\n  test: ^1.33.0\n  mockito: ^5.0.0\n' > "$dsroot/dart/pubspec.yaml"
deps_fails "another development dependency" "development dependencies other than test and lints"
good_pubspec
for lib in io ffi mirrors; do
  printf "import 'dart:%s';\n" "$lib" > "$dsroot/dart/lib/src/bad.dart"
  deps_fails "import of dart:$lib" "dart:mirrors, dart:ffi or dart:io under lib/"
  printf 'export "dart:%s" show Foo;\n' "$lib" > "$dsroot/dart/lib/src/bad.dart"
  deps_fails "export of dart:$lib" "dart:mirrors, dart:ffi or dart:io under lib/"
done
printf "  import   'dart:io' ;\n" > "$dsroot/dart/lib/src/bad.dart"
deps_fails "an indented import of dart:io" "src/bad.dart:1:"
rm -f "$dsroot/dart/lib/src/bad.dart"
# dart:io in the tests and the tool programs is allowed: the check reads lib/ only
printf "import 'dart:io';\n" > "$dsroot/dart/test/core/io_test.dart"
printf "import 'dart:io';\n" > "$dsroot/dart/tool/speed.dart"
out="$(run_dart "$dsroot")"; code=$?
[ "$code" -eq 0 ] || bad "dart: dart:io outside lib/ failed the suite (exit $code): $out"
rm -f "$dsroot/dart/test/core/io_test.dart"
: > "$dsroot/dart/tool/speed.dart"

# D6. on GitHub Actions the step lines also go out as ONE notice titled "dart suite timing"
out="$(run_dart "$dsroot" GITHUB_ACTIONS=true)"; code=$?
[ "$code" -eq 0 ] || bad "dart: the notice run failed (exit $code): $out"
[ "$(grep -c '^::notice title=dart suite timing::' <<< "$out")" -eq 1 ] || bad "dart: not exactly one notice titled 'dart suite timing': $out"
grep -q '^::notice .*dart total took [0-9]* s in 7 steps' <<< "$out" || bad "dart: the notice has no total line over 7 steps: $out"

# D7 (AC-3, AC-4). the wiring: the dart service runs its own suite on the image tool-pins.txt names, a changed tag is
# rejected, and test.yml runs Dart in the Go entry of the suites matrix within 20 jobs
dart_service_line() { # compose file, key: the value of "    key:" in the dart service's block
  awk -v svc="  dart:" -v key="    $2: " '
    $0 == svc { inside = 1; next }
    inside && /^  [^ ]/ { inside = 0 }
    inside && index($0, key) == 1 { print substr($0, length(key) + 1); exit }
  ' "$1"
}
dart_pin_error() { # compose file: nothing when the dart image is dart:<tool-pins.txt dart>, else the reason
  local pin image
  pin="$(bash "$here/tool-pin.sh" dart)" || { echo "tool-pins.txt has no dart pin"; return; }
  image="$(dart_service_line "$1" image)"
  [ "$image" = "dart:$pin" ] || echo "the compose image is $image, not dart:$pin"
}
compose="$repo/docker-compose.test.yml"
[ -z "$(dart_pin_error "$compose")" ] || bad "dart: $(dart_pin_error "$compose")"
sed 's#^    image: dart:3\.13\.7$#    image: dart:3.13.8#' "$compose" > "$work/compose-dart-bumped.yml"
cmp -s "$compose" "$work/compose-dart-bumped.yml" && bad "dart: the bumped compose copy is unchanged (the pin test reads another tag?)"
[ -n "$(dart_pin_error "$work/compose-dart-bumped.yml")" ] || bad "dart: a compose image tag that differs from the pin was not rejected"
sed 's#^dart==.*#dart==3.13.8#' "$here/tool-pins.txt" > "$work/pins-dart-bumped.txt"
[ "$(awk -F'==' '$1 == "dart" { print $2 }' "$work/pins-dart-bumped.txt")" != "$(bash "$here/tool-pin.sh" dart)" ] || bad "dart: the bumped pins copy is unchanged"
[ "$(dart_service_line "$compose" command)" = "[\"exec /src/.github/workflows/run-suite.sh dart\"]" ] || bad "dart: the compose service does not run run-suite.sh dart"
case "$(dart_service_line "$compose" image)" in dart:3.13.*) ;; *) bad "dart: the compose image is not a 3.13 tag" ;; esac
dart_matrix="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import yaml_get
jobs = yaml_get.load(sys.argv[2])["jobs"]
jobs_count = 0
for job in jobs.values():
    inc = (job.get("strategy") or {}).get("matrix", {}).get("include")
    jobs_count += len(inc) if isinstance(inc, list) else 1
inc = jobs["suites"]["strategy"]["matrix"]["include"]
go = [e for e in inc if "go" in str(e.get("lang")).split()]
dart = [e for e in inc if "dart" in str(e.get("lang")).split()]
print(jobs_count, len(go), len(dart), go == dart and len(go) == 1)' "$here/../../scripts/ci" "$here/test.yml" </dev/null)" || bad "dart: test.yml could not be read"
read -r dart_jobs dart_go dart_dart dart_same <<< "$dart_matrix"
[ "${dart_jobs:-99}" -le 20 ] || bad "dart: test.yml makes $dart_jobs jobs, more than 20"
[ "$dart_go" = 1 ] && [ "$dart_dart" = 1 ] && [ "$dart_same" = True ] || bad "dart: test.yml does not run Dart once, in the Go entry of the suites matrix: [$dart_matrix]"
for file in dart/pubspec.yaml dart/lib/packbin.dart; do
  grep -qxF "            $file \\" "$here/test.yml" || bad "dart: the scaffold job does not check that $file exists"
done
grep -qF 'ls dart/test/*/*_test.dart' "$here/test.yml" || bad "dart: the scaffold job does not check that the Dart tests exist"
# the service passes GITHUB_ACTIONS through as a bare key and keeps the pub cache and .dart_tool in volumes
if ! awk '$0 == "  dart:" { inside = 1; next } inside && /^  [^ ]/ { inside = 0 } inside' "$compose" | grep -qx '      GITHUB_ACTIONS:'; then
  bad "dart: the compose service does not pass GITHUB_ACTIONS through as a bare key"
fi
for volume in 'pub-cache:/pub-cache' 'dart-tool:/src/dart/.dart_tool'; do
  awk '$0 == "  dart:" { inside = 1; next } inside && /^  [^ ]/ { inside = 0 } inside' "$compose" | grep -qxF "      - $volume" \
    || bad "dart: the compose service has no volume $volume"
done

# D8 (AC-2, real tools). with a real dart: an unformatted file, an analyzer info and a failing test each fail their step,
# a clean package passes them. The test rows need `dart pub get --offline` to find package:test in the pub cache.
if command -v dart > /dev/null && dart --version > /dev/null 2>&1; then
  # shellcheck source=run-suite-dart.sh
  . "$here/run-suite-dart.sh"
  real="$work/dartreal"
  mkdir -p "$real/lib" "$real/test"
  printf 'name: probe\nenvironment:\n  sdk: ^3.13.0\ndev_dependencies:\n  test: ^1.33.0\n' > "$real/pubspec.yaml"
  printf 'linter:\n  rules:\n    - avoid_print\n' > "$real/analysis_options.yaml"
  printf 'int one() => 1;\n' > "$real/lib/a.dart"
  printf "import 'package:test/test.dart';\n\nvoid main() {\n  test('passes', () => expect(1, 1));\n}\n" > "$real/test/a_test.dart"
  dart_fmt "$real" > /dev/null || bad "dart (real): a formatted package failed dart format"
  printf 'int  one()=>1;\n' > "$real/lib/a.dart"
  if dart_fmt "$real" > /dev/null 2>&1; then bad "dart (real): an unformatted file passed dart format"; fi
  printf 'int one() => 1;\n' > "$real/lib/a.dart"
  # analyze needs the resolved packages (package:test is imported by the test file)
  if perl -e 'alarm 120; exec @ARGV' -- dart pub get --offline --directory "$real" < /dev/null > /dev/null 2>&1; then
    dart_analyze "$real" > /dev/null 2>&1 || bad "dart (real): a clean package failed dart analyze"
    printf "void f() {\n  print('x');\n}\n" > "$real/lib/b.dart"
    if dart_analyze "$real" > /dev/null 2>&1; then bad "dart (real): an analyzer info passed dart analyze --fatal-infos"; fi
    rm -f "$real/lib/b.dart"
    dart_test "$real" > /dev/null 2>&1 || bad "dart (real): a passing test failed dart test"
    printf "import 'package:test/test.dart';\n\nvoid main() {\n  test('fails', () => expect(1, 2));\n}\n" > "$real/test/a_test.dart"
    if dart_test "$real" > /dev/null 2>&1; then bad "dart (real): a failing test passed dart test"; fi
  else
    echo "run-suite-dart.test.sh: skipped the real analyze and test rows: package:test is not in the pub cache"
  fi
else
  echo "run-suite-dart.test.sh: skipped the real dart rows: no dart on PATH"
fi

if [ -n "${dart_alone:-}" ]; then
  if [ "$fail" -eq 0 ]; then echo "run-suite-dart.test.sh: all checks passed"; fi
  exit "$fail"
fi
