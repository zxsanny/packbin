#!/usr/bin/env bash
# The rust helpers of run-suite.sh (AZ-4288), sourced from its `rust` case so that file stays under 500 lines,
# as run-suite-dart.sh is. The caller defines $root and runs each step through `run`; a step sets $failure.
# shellcheck disable=SC2154

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

# The suite image (rust:1.98) has no clippy; the component is added before the first use, and a failure to get it fails
# the suite by name, so a missing clippy is never a pass (AZ-3443 AC-3).
rust_clippy_component() {
  if ! rustup component add clippy; then
    failure="rust clippy component could not be installed"
    printf 'run-suite: %s\n' "$failure" >&2
    return 1
  fi
}

# The lib and every test target of one feature set ($1: none, default, all or a feature list) compile, and print no
# rustc or clippy warning (AZ-3357, AZ-3443). The test runs name most no-std targets one by one (`--test <name>`), so a
# test file without its feature gate built in no run (loop 76: 22 files). `cargo clippy --lib --tests` gives the same
# compile errors as `cargo test --no-run` without code generation (the 7 no-std sets cost about 64 s more cold on 4 CPUs
# with `--no-run`, loop 79, on the job that sets the CI wall), plus the clippy lints, in one pass per set. Cargo replays
# the warnings of a cached check; stdout and stderr are read together. The messages keep the AZ-3357 wording.
rust_test_build() {
  local set="$1" out
  local -a features
  case "$set" in
    default) features=() ;;
    all) features=(--all-features) ;;
    none) features=(--no-default-features) ;;
    *) features=(--no-default-features --features "$set") ;;
  esac
  if ! out="$(cargo clippy --manifest-path "$root/rust/Cargo.toml" ${features[@]+"${features[@]}"} --lib --tests 2>&1)"; then
    printf '%s\n' "$out"
    failure="rust test build of feature set $set failed"
    printf 'run-suite: %s\n' "$failure" >&2
    return 1
  fi
  printf '%s\n' "$out"
  if grep -q '^warning:' <<< "$out"; then
    failure="rust test build of feature set $set printed a warning"
    printf 'run-suite: %s:\n' "$failure" >&2
    grep '^warning:' <<< "$out" >&2
    return 1
  fi
}
