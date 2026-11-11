#!/usr/bin/env bash
# The Dart steps of run-suite.sh (AZ-4145), sourced from its `dart` case so that file stays under 500 lines and
# run-suite-dart.test.sh can call each step on its own. The caller defines $root, $failure and missing_manifest.
# Every step runs in the package directory $1 (dart/), and none of them is a quiet mode.
# shellcheck disable=SC2154

dart_pub_get() {
  (cd "$1" && dart pub get)
}

# DT-9: format and analyze give no change and no issue of any severity (an info fails: --fatal-infos).
dart_fmt() {
  (cd "$1" && dart format --output=none --set-exit-if-changed .)
}

dart_analyze() {
  (cd "$1" && dart analyze --fatal-infos)
}

# `-r expanded` prints one line per test; the default compact reporter rewrites one line and hides the names.
dart_test() {
  (cd "$1" && dart test -r expanded)
}

# DT-5: the seeded random unpack run (AZ-4139) lives in test/limits/seeded_run_test.dart and reads its duration from
# PACKBIN_FUZZ_SECONDS (as the Swift fuzz run does). Until that file exists the step says it is not present; once it
# exists the step runs it for 60 s, and a run shorter than asked fails, since a test that ignored the duration would
# otherwise pass in seconds.
dart_seeded() {
  local seconds="${PACKBIN_FUZZ_SECONDS:-60}" start elapsed
  if [ ! -f "$1/test/limits/seeded_run_test.dart" ]; then
    echo "run-suite: dart seeded unpack run: not present (dart/test/limits/seeded_run_test.dart does not exist yet)"
    return 0
  fi
  start=$(date +%s)
  (cd "$1" && env PACKBIN_FUZZ_SECONDS="$seconds" dart test -r expanded test/limits/seeded_run_test.dart) || return 1
  elapsed=$(( $(date +%s) - start ))
  if [ "$elapsed" -lt "$seconds" ]; then
    printf 'run-suite: the dart seeded unpack run took %s s, under the %s s asked for\n' "$elapsed" "$seconds" >&2
    return 1
  fi
}

# DT-8: the speed bounds hold for a compiled executable, not for the VM's JIT. The program exits 1 over a bound.
dart_speed() {
  local out status
  out="$(mktemp -d "${TMPDIR:-/tmp}/packbin-dart-speed.XXXXXX")" || return 1
  (cd "$1" && dart compile exe tool/speed.dart -o "$out/speed")
  status=$?
  if [ "$status" -eq 0 ]; then
    "$out/speed"
    status=$?
  fi
  rm -rf "$out"
  return "$status"
}

# DT-11: 0 runtime dependencies (no `dependencies:` section; the sdk lives under `environment:`), development
# dependencies `test` and `lints` only, and no import or export of dart:mirrors, dart:ffi or dart:io under lib/.
dart_deps() {
  local pubspec="$1/pubspec.yaml" extra hits
  if grep -qE '^(dependencies|dependency_overrides):' "$pubspec"; then
    printf 'run-suite: %s has a dependencies or dependency_overrides section: the package has no runtime dependency\n' "$pubspec" >&2
    return 1
  fi
  extra="$(awk '
    /^[A-Za-z_]+:/ { inside = ($1 == "dev_dependencies:"); next }
    inside && /^  [A-Za-z0-9_]+:/ { name = $1; sub(/:$/, "", name); if (name != "test" && name != "lints") print name }
  ' "$pubspec")"
  if [ -n "$extra" ]; then
    printf 'run-suite: %s has development dependencies other than test and lints:\n%s\n' "$pubspec" "$extra" >&2
    return 1
  fi
  hits="$(grep -rnE --include='*.dart' "^[[:space:]]*(import|export)[[:space:]]+['\"]dart:(mirrors|ffi|io)['\"]" "$1/lib")"
  if [ -n "$hits" ]; then
    printf 'run-suite: the dart package imports dart:mirrors, dart:ffi or dart:io under lib/:\n%s\n' "$hits" >&2
    return 1
  fi
}

# The whole Dart suite on the package at $root/dart: a tree without pubspec.yaml fails, as every language does.
dart_suite() {
  local dir="$root/dart"
  if [ ! -f "$dir/pubspec.yaml" ]; then
    missing_manifest "$dir/pubspec.yaml"
    return
  fi
  run dart_deps "$dir"
  run dart_pub_get "$dir"
  run dart_fmt "$dir"
  run dart_analyze "$dir"
  run dart_test "$dir"
  run dart_seeded "$dir"
  run dart_speed "$dir"
}
