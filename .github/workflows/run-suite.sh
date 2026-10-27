#!/usr/bin/env bash
set -uo pipefail

lang="${1:?language}"
root="${SRC_ROOT:-.}"
fixture="${FIXTURE:-$root/fixtures/golden.hex}"
results="${TEST_RESULTS:-$root/test-results}"
ok=0
failure=
started=$(date +%s)
steps=0
timing_lines=

grep -qx '4001000065cd1d00a3e1110100' "$fixture" || ok=1

# A workflow-command message escaped as GitHub's toolkit does: % first, then CR and LF.
notice_escape() {
  local s="${1//"%"/%25}"
  s="${s//$'\r'/%0D}"
  printf '%s' "${s//$'\n'/%0A}"
}

# A timing line goes to stderr as it is and is kept, escaped, for the notice (lines joined by %0A).
timing_say() {
  printf '%s\n' "$1" >&2
  timing_lines="${timing_lines:+$timing_lines%0A}$(notice_escape "$1")"
}

run() {
  if [ "$ok" -ne 0 ]; then
    return
  fi
  local step_started step_label step_line
  step_started=$(date +%s)
  "$@" || ok=1
  # The time of each step, so a slow stage shows which step costs it (swift_opts is the same on every Swift step, so
  # it is cut from the label). The cut runs on the joined line: ${*//...} would try the pattern on each word alone.
  step_label="$*"
  step_label="${step_label// --package-path * --force-resolved-versions/}"
  printf -v step_line 'run-suite: %s step took %s s: %s' "$lang" "$(( $(date +%s) - step_started ))" "${step_label:0:110}"
  steps=$((steps + 1))
  timing_say "$step_line"
}

# A suite whose manifest is missing has nothing to run: it fails, as Go always did (AZ-2448 AC-3, AZ-2477), so a
# tree that lost a language cannot turn the check green. Whether a language is published is decided by the
# publish gate (`publish-gate.sh`, AC-15), not by this script.
missing_manifest() {
  printf 'run-suite: %s is missing; the %s suite has nothing to run\n' "$1" "$lang" >&2
  ok=1
}

# Go (golang:1.27): every step runs in the module directory $1 through `go -C`.
go_fmt() {
  local unformatted
  unformatted="$(cd "$1" && gofmt -l .)" || return 1
  if [ -n "$unformatted" ]; then
    printf 'run-suite: gofmt -l lists files that are not gofmt-formatted:\n%s\n' "$unformatted" >&2
    return 1
  fi
}

# The 60 s fuzz run of the package that has the FuzzUnpack target (AZ-2444). Until that target
# exists the step says it is skipped; the line goes away by itself once the target is there.
go_fuzz() {
  local listed pkg
  listed="$(go -C "$1" test -list '^FuzzUnpack$' ./...)" || return 1
  pkg="$(printf '%s\n' "$listed" | awk '$0 == "FuzzUnpack" { found = 1; next } /^ok[ \t]/ { if (found) { print $2; exit } }')"
  if [ -z "$pkg" ]; then
    echo "run-suite: go fuzz step skipped: the package has no FuzzUnpack target yet"
    return 0
  fi
  # -fuzzminimizetime=0: the default minimises every new input for up to 60 s, which left 121k execs in a 60 s run
  # (1.4M without it, AZ-2444 report).
  go -C "$1" test -run='^$' -fuzz='^FuzzUnpack$' -fuzztime=60s -fuzzminimizetime=0 "$pkg"
}

# One dependency at most (GO-11, G-3): go.mod's direct requirements and the modules of every package
# the package and its tests build are the main module and golang.org/x/crypto. `go list -m all` alone
# cannot be the check: it always lists x/crypto's own requirements (x/sys, x/net, x/term, x/text).
go_deps() {
  local main direct built extra
  main="$(go -C "$1" list -m)" || return 1
  direct="$(go -C "$1" list -m -f '{{if not (or .Main .Indirect)}}{{.Path}}{{end}}' all)" || return 1
  built="$(go -C "$1" list -deps -test -f '{{with .Module}}{{.Path}}{{end}}' ./...)" || return 1
  extra="$(printf '%s\n%s\n' "$direct" "$built" | grep -vxF -e '' -e "$main" -e 'golang.org/x/crypto' | sort -u)"
  if [ -n "$extra" ]; then
    printf 'run-suite: go depends on modules other than golang.org/x/crypto:\n%s\n' "$extra" >&2
    return 1
  fi
}

# Swift (swift:6.3.3): every step runs on the root Package.swift with these options.
# The compose services put the build output outside the mounted tree (PACKBIN_SWIFT_SCRATCH); --force-resolved-versions
# builds only what Package.resolved pins and never rewrites it (Go's -mod=readonly).
swift_opts=(--package-path "$root" --scratch-path "${PACKBIN_SWIFT_SCRATCH:-$root/.build}" --force-resolved-versions)
# SW-9: 0 warnings in the release build. Warnings as errors and complete concurrency checking are given here, never in
# Package.swift: an unsafe flag there makes the package unusable as a dependency.
swift_strict=(-Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete)
swift_tests=

# Both halves of the Swift tree: the manifest every consumer resolves and the sources it points at.
swift_tree() {
  local missing=0
  [ -f "$root/Package.swift" ] || { missing_manifest "$root/Package.swift"; missing=1; }
  [ -d "$root/swift" ] || { missing_manifest "$root/swift"; missing=1; }
  return "$missing"
}

# A failed fetch of the pinned dependency is not a test failure: the report row says which it was.
swift_resolve() {
  if ! swift package "${swift_opts[@]}" resolve; then
    failure="swift dependency resolve failed"
    return 1
  fi
}

# The test identifiers of the build in the scratch path (`Module.Suite/test()`), for the steps that run one suite:
# the debug build, or the one named by the options in $@ (the speed part lists its release build).
swift_list() {
  swift_tests="$(swift test list "${swift_opts[@]}" "$@" --skip-build)" || return 1
  printf '%s\n' "$swift_tests"
}

# The 60 s unpack fuzz run of the FuzzTests suite (AZ-2517), which reads its duration from PACKBIN_FUZZ_SECONDS.
# Until that suite exists the step says it is skipped. A run shorter than asked fails: a suite that ignored the
# duration would otherwise pass in seconds.
swift_fuzz() {
  local seconds="${PACKBIN_FUZZ_SECONDS:-60}" start elapsed
  if ! grep -q '\.FuzzTests/' <<< "$swift_tests"; then
    echo "run-suite: swift fuzz step skipped: the package has no FuzzTests suite yet"
    return 0
  fi
  start=$(date +%s)
  env PACKBIN_FUZZ_SECONDS="$seconds" swift test "${swift_opts[@]}" --skip-build --verbose --filter '\.FuzzTests/' || return 1
  elapsed=$(( $(date +%s) - start ))
  if [ "$elapsed" -lt "$seconds" ]; then
    printf 'run-suite: the swift fuzz step ran %s s, under the %s s asked for\n' "$elapsed" "$seconds" >&2
    return 1
  fi
}

# CS-11 (AZ-2665): the string speed bound (100,000 round trips in 1 s) holds for a release build only; the test asserts
# 6 s under debug assertions, which is all `cargo test` above builds. A filter that matches nothing passes, so the
# test must be in the list of the release build.
rust_speed() {
  local manifest="$root/rust/Cargo.toml" listed
  listed="$(cargo test --manifest-path "$manifest" --release --lib -- --list)" || return 1
  if ! grep -q 'ac8_one_hundred_thousand_round_trips' <<< "$listed"; then
    echo "run-suite: rust has no string speed test (ac8_one_hundred_thousand_round_trips); the release-build step has nothing to run" >&2
    return 1
  fi
  # EC-13 (AZ-2689): the message ECC bounds (1,000 repairs and 1,000 packs of a 254-byte block in 1 s) hold for a release
  # build only, and a debug build is far slower. The listing must hold both ec13_ tests, or the filter runs nothing.
  if [ "$(grep -c 'ec13_' <<< "$listed")" -lt 2 ]; then
    echo "run-suite: rust has fewer than two message ECC speed tests (ec13_); the release-build step has nothing to run" >&2
    return 1
  fi
  cargo test --manifest-path "$manifest" --release --lib ac8_one_hundred_thousand_round_trips -- --nocapture || return 1
  cargo test --manifest-path "$manifest" --release --lib ec13_ -- --nocapture
}

# SW-8: the speed bound holds for a release build only. A filter that matches nothing passes, so the suite must exist.
# SW-9: this is the one release build of the suite, with the tests, so it carries the strict flags and the 0 warnings
# cover the test targets too. The single run has listed the tests of its debug build by now and fails before the
# release build. The speed part has no debug or sanitizer build to list from: it builds first and lists the tests of its
# own release build.
swift_speed() {
  local built=
  if [ "${swift_part:-all}" = speed ]; then
    swift build "${swift_opts[@]}" -c release --build-tests "${swift_strict[@]}" || return 1
    built=1
    swift_list -c release || return 1
  fi
  if ! grep -q '\.SpeedTests/' <<< "$swift_tests"; then
    echo "run-suite: swift has no SpeedTests suite; the release-build speed step has nothing to run" >&2
    return 1
  fi
  # CS-11 (AZ-2665): the string speed test is its own suite, and `\.SpeedTests/` does not select it.
  if ! grep -q '\.TextSpeedTests/' <<< "$swift_tests"; then
    echo "run-suite: swift has no TextSpeedTests suite; the release-build string speed step has nothing to run" >&2
    return 1
  fi
  if [ -z "$built" ]; then swift build "${swift_opts[@]}" -c release --build-tests "${swift_strict[@]}" || return 1; fi
  # The 1 MiB hostile unpack (FuzzTests/mebibyte, SW-4) is timed in the same release run: a debug build is about 7 times slower.
  swift test "${swift_opts[@]}" -c release --skip-build --verbose --filter '\.SpeedTests/' --filter '\.TextSpeedTests/' --filter '\.FuzzTests/mebibyte'
}

# The thread sanitizer runs the suites that use threads (the concurrency suites, text and byte); the other suites
# are single-threaded, where it only costs time. A suite gone from the list fails the step, since a filter that matches
# nothing passes with no test run, and so does a test file that uses threads outside those suites.
swift_sanitized() {
  local suite threaded
  for suite in ConcurrencyTests TextConcurrencyTests; do
    if ! grep -q "\.$suite/" <<< "$swift_tests"; then
      printf 'run-suite: swift has no %s suite; the thread-sanitizer run would not run it\n' "$suite" >&2
      return 1
    fi
  done
  if [ -d "$root/swift/Tests" ]; then
    threaded="$(grep -rlE 'withTaskGroup|withThrowingTaskGroup|Task(\.detached)? *\{|Thread\.|DispatchQueue' "$root/swift/Tests" \
      | grep -vE '/(Concurrency|TextConcurrency)Tests\.swift$')"
    if [ -n "$threaded" ]; then
      printf 'run-suite: swift test files use threads outside the thread-sanitizer suites:\n%s\n' "$threaded" >&2
      return 1
    fi
  fi
  swift test "${swift_opts[@]}" --skip-build --sanitize=thread --verbose \
    --filter '\.ConcurrencyTests/' --filter '\.TextConcurrencyTests/'
}

# SW-11: exactly one package dependency, swift-crypto (what swift-crypto itself requires is its business), no
# unsafe flags, and every target of the package's own is a Swift target (no C, C++, system library or binary target).
swift_deps() {
  local described dumped types direct
  described="$(swift package "${swift_opts[@]}" describe --type json)" || return 1
  dumped="$(swift package "${swift_opts[@]}" dump-package)" || return 1
  types="$(sed -n 's/^ *"module_type" : "\([^"]*\)".*/\1/p' <<< "$described")"
  if [ -z "$types" ]; then
    echo "run-suite: swift package describe lists no targets; the dependency check cannot read it" >&2
    return 1
  fi
  if grep -vxF SwiftTarget <<< "$types" >/dev/null; then
    printf 'run-suite: the swift package has targets that are not Swift targets:\n%s\n' "$(grep -vxF SwiftTarget <<< "$types" | sort -u)" >&2
    return 1
  fi
  if grep -qF '"unsafeFlags"' <<< "$dumped"; then
    echo "run-suite: Package.swift sets unsafe flags (they make the package unusable as a dependency)" >&2
    return 1
  fi
  direct="$(sed -n 's/^ *"identity" : "\([^"]*\)".*/\1/p' <<< "$described" | grep -vxF swift-crypto | sort -u)"
  if [ -n "$direct" ]; then
    printf 'run-suite: swift depends on packages other than swift-crypto:\n%s\n' "$direct" >&2
    return 1
  fi
  if ! sed -n 's/^ *"identity" : "\([^"]*\)".*/\1/p' <<< "$described" | grep -qxF swift-crypto; then
    echo "run-suite: the swift package does not depend on swift-crypto (SW-11 asks for exactly one dependency)" >&2
    return 1
  fi
}

case "$lang" in
  csharp)
    shopt -s nullglob
    projects=("$root"/csharp/*.csproj)
    if [ "${#projects[@]}" -gt 0 ]; then
      run env MSBUILDDISABLENODEREUSE=1 dotnet test "$root/csharp" -v n --nologo
      # The same suite against the netstandard2.0 build of the package.
      run env MSBUILDDISABLENODEREUSE=1 dotnet test "$root/csharp" -v n --nologo -p:PackbinTarget=netstandard2.0
    else
      missing_manifest "$root/csharp/*.csproj"
    fi
    ;;
  typescript)
    if [ -f "$root/typescript/package.json" ]; then
      run bash -lc "cd '$root/typescript' && if [ ! -f node_modules/typescript/lib/tsc.js ]; then npm ci; fi && npm test"
    else
      missing_manifest "$root/typescript/package.json"
    fi
    ;;
  python)
    if [ -f "$root/python/pyproject.toml" ]; then
      venv="${PACKBIN_PYTEST_VENV:-/tmp/packbin-pytest}"
      if [ ! -x "$venv/bin/pytest" ]; then
        if pytest_pin="$(bash "$root/.github/workflows/tool-pin.sh" pytest)"; then
          # --clear empties the directory, so only a missing, empty or venv directory may be rebuilt,
          # and never through a symlink (it would empty the target).
          if [ -L "$venv" ]; then
            printf 'run-suite: %q is a symlink; not rebuilding through it\n' "$venv" >&2
            ok=1
          elif [ -e "$venv" ] && [ ! -f "$venv/pyvenv.cfg" ] && [ -n "$(ls -A "$venv" 2>/dev/null)" ]; then
            printf 'run-suite: %q exists, is not empty and is not a python venv; not overwriting it\n' "$venv" >&2
            ok=1
          elif python -m venv --clear "$venv" </dev/null; then
            "$venv/bin/pip" install --only-binary=:all: "pytest==$pytest_pin" || ok=1
          else
            printf "run-suite: cannot create the python venv %q (is 'python' on PATH?)\n" "$venv" >&2
            ok=1
          fi
        else
          ok=1
        fi
      fi
      if [ "$ok" -eq 0 ] && ! "$venv/bin/python" -c 'import pytest' </dev/null >/dev/null 2>&1; then
        printf 'run-suite: python venv %q is unusable: its interpreter or pytest does not start.\n' "$venv" >&2
        printf 'run-suite: remove it and run again so it is rebuilt: rm -rf %q\n' "$venv" >&2
        ok=1
      fi
      run "$venv/bin/python" -m pytest -v --tb=short "$root/python/tests"
    else
      missing_manifest "$root/python/pyproject.toml"
    fi
    ;;
  rust)
    if [ -f "$root/rust/Cargo.toml" ]; then
      run cargo test --manifest-path "$root/rust/Cargo.toml" -- --nocapture
      # the heap-free API builds and passes with `std` and `alloc` off (AZ-2749)
      run cargo test --manifest-path "$root/rust/Cargo.toml" --no-default-features --test nostd_flat_tests -- --nocapture
      # the parts of the heap-free API behind a feature, on without `std` and off (AZ-2754, AZ-2755), and the hostile corpus and
      # the fixture differential on the core with them on (AZ-2757): the default
      # run above already covers the two "off" tests and the rest with the features off
      run cargo test --manifest-path "$root/rust/Cargo.toml" --no-default-features --features text --test nostd_text_tests -- --nocapture
      run cargo test --manifest-path "$root/rust/Cargo.toml" --no-default-features --features ecc --test nostd_ecc_tests -- --nocapture
      run cargo test --manifest-path "$root/rust/Cargo.toml" --features text,ecc --test nostd_dict_tests --test nostd_text_differential_tests --test nostd_hostile_tests --test nostd_hostile_pack_tests --test nostd_fixture_differential_tests --test nostd_raw_repeat_tests -- --nocapture
      # frame mode (AZ-3203): the shared fixture without `std` (nothing allocates) and with it, the crate's own tests, and
      # frame mode with message ECC in one build
      run cargo test --manifest-path "$root/rust/Cargo.toml" --no-default-features --features frame --test frame_vectors_tests -- --nocapture
      run cargo test --manifest-path "$root/rust/Cargo.toml" --features frame --test frame_vectors_tests -- --nocapture
      run cargo test --manifest-path "$root/rust/Cargo.toml" --features frame --lib frame_ -- --nocapture
      run cargo test --manifest-path "$root/rust/Cargo.toml" --features frame,ecc --lib frame_ -- --nocapture
      run cargo test --manifest-path "$root/rust/Cargo.toml" --features frame --doc -- --nocapture
      # all features together (AZ-3338 AC-6)
      run cargo test --manifest-path "$root/rust/Cargo.toml" --all-features -- --nocapture
      run rust_speed
    else
      missing_manifest "$root/rust/Cargo.toml"
    fi
    ;;
  cpp)
    if [ -f "$root/cpp/Makefile" ]; then
      run make -C "$root/cpp" test
    else
      missing_manifest "$root/cpp/Makefile"
    fi
    ;;
  java)
    if [ -x "$root/java/test.sh" ] || [ -f "$root/java/test.sh" ]; then
      run bash "$root/java/test.sh"
    else
      missing_manifest "$root/java/test.sh"
    fi
    ;;
  go)
    # In the CI container Go runs as root on a checkout owned by the runner user, so git refuses it
    # ("dubious ownership") and `go list -test` stops with "error obtaining VCS status" (CI run 38422313279).
    # No step needs the VCS stamp, so every go command here runs with -buildvcs=false.
    export GOFLAGS="${GOFLAGS:+$GOFLAGS }-buildvcs=false"
    # A missing manifest fails: a Go suite that runs nothing must not pass (AZ-2448 AC-3).
    if [ -f "$root/go/go.mod" ]; then
      run go_fmt "$root/go"
      run go -C "$root/go" vet ./...
      run go -C "$root/go" test -race -count=1 -v ./...
      # AC-10 (1 s for 100 000 round trips) is a bound on the production build: the race detector costs about 5x,
      # so TestAC7SpeedRoundTrips asserts it only without -race and this step runs it there.
      run go -C "$root/go" test -run='^TestAC7SpeedRoundTrips$' -count=1 -v ./...
      run go_fuzz "$root/go"
      run go_deps "$root/go"
    else
      missing_manifest "$root/go/go.mod"
    fi
    ;;
  swift)
    # PACKBIN_SWIFT_PART splits the suite in three for CI (AZ-2600, AZ-2607, AZ-2625), each part its own job with its own
    # build output, so no job is the sum of all of them. `tests`: the debug build, the tests and the fuzz run. `gates`:
    # the thread-sanitizer build and run, the dependency check. `speed`: the one release build, with the tests and the
    # strict flags of SW-9, and the speed run. Unset or `all` runs every step in one run, as the Mac does, with that one
    # release build. Every step is in exactly one part; resolve and list are the only repeats (a part cannot use another
    # part's build output or test list).
    swift_part="${PACKBIN_SWIFT_PART:-all}"
    swift_plan=
    case "$swift_part" in
      all) swift_plan="resolve debug test list fuzz tsan sanitized speed deps" ;;
      tests) swift_plan="resolve debug test list fuzz" ;;
      gates) swift_plan="resolve tsan list sanitized deps" ;;
      speed) swift_plan="resolve speed" ;;
      *)
        printf 'run-suite: PACKBIN_SWIFT_PART is %q, not all, tests, gates or speed\n' "$swift_part" >&2
        ok=1
        ;;
    esac
    # A tree without Package.swift or swift/ fails, as every other language does without its manifest (AC-3).
    if [ "$ok" -eq 0 ] && swift_tree; then
      for swift_step in $swift_plan; do
        case "$swift_step" in
          resolve) run swift_resolve ;;
          # The tests are built first, so the verbose test output is not buried under the compiler command lines.
          debug) run swift build "${swift_opts[@]}" --build-tests ;;
          test) run swift test "${swift_opts[@]}" --skip-build --verbose ;;
          # The gates part has no debug test build of its own: it lists the tests of the sanitizer build.
          list) run swift_list ;;
          # Before the sanitizer run, which rebuilds the debug build with -sanitize=thread.
          fuzz) run swift_fuzz ;;
          # SW-14: a race reported by the thread sanitizer fails the run (its exit code is 66).
          tsan) run swift build "${swift_opts[@]}" --build-tests --sanitize=thread ;;
          sanitized) run swift_sanitized ;;
          speed) run swift_speed ;;
          deps) run swift_deps ;;
        esac
      done
    fi
    ;;
  *)
    echo "unknown language: $lang" >&2
    ok=1
    ;;
esac

elapsed=$(( $(date +%s) - started ))
elapsed_ms=$(( elapsed * 1000 ))
# C3 (AZ-2627): CI keeps a Swift part's build output between runs and says whether it restored it (PACKBIN_SWIFT_CACHE
# hit or miss); the notice carries that. Unset on the Mac, which builds from nothing.
if [ "$lang" = swift ] && [ -n "${PACKBIN_SWIFT_CACHE:-}" ]; then
  timing_say "run-suite: swift cache $PACKBIN_SWIFT_CACHE"
fi
timing_say "run-suite: $lang total took $elapsed s in $steps steps"
# On GitHub Actions the timing lines also go out as ONE notice annotation, as the publish gate's do
# (publish-timing.test.sh): a job's check-run annotations are readable without a token, its log is not (AZ-2607).
# Whether the run passed or not; a step skipped after a failure has no line. The title is a property value, so it
# also escapes ':' and ','.
if [ "${GITHUB_ACTIONS:-}" = true ]; then
  title="$lang suite timing"
  if [ "$lang" = swift ] && [ "${swift_part:-all}" != all ]; then title="swift ($swift_part) suite timing"; fi
  title="$(notice_escape "$title")"
  title="${title//:/%3A}"
  printf '::notice title=%s::%s\n' "${title//,/%2C}" "$timing_lines"
fi
if [ "$ok" -eq 0 ]; then
  result=PASS
  message=
else
  result=FAIL
  message="${failure:-suite failed}"
fi
TEST_RESULTS="$results" SRC_ROOT="$root" bash "$root/.github/workflows/report-row.sh" \
  "$lang" "$lang suite" "$elapsed_ms" "$result" "$message"
exit "$ok"
