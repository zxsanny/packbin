#!/usr/bin/env bash
# run-suite.sh rust, the clippy component (AZ-3443 AC-3). Sourced by run-suite.test.sh, which defines bad, $work,
# $present, $toolbin and $suite_sh (the script under test). `rustup` and `cargo` are fakes that log their arguments
# to $GO_LOG, so no toolchain and no network are used. A component that cannot be added fails the suite by name, in the
# report row too, and no clippy run starts.

# shellcheck disable=SC2154
# C1. Arrange: the fake rustup fails `component add clippy`
rm -f "$work/bare.rows"; : > "$work/go.log"
# Act
out="$(env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
  FAKE_FAIL_ON="component add clippy" PATH="$toolbin:$PATH" perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" rust </dev/null 2>&1)"; code=$?
# Assert
[ "$code" -ne 0 ] || bad "rust: a suite whose clippy component could not be added passed"
case "$out" in *"run-suite: rust clippy component could not be installed"*) ;; *) bad "rust: clippy is not named: $out" ;; esac
grep -Eqx "report-row rust rust suite [0-9]+ FAIL rust clippy component could not be installed" "$work/bare.rows" \
  || bad "rust: the report row does not name clippy: $(cat "$work/bare.rows" 2>&1)"
if grep -q '^cargo clippy ' "$work/go.log"; then bad "rust: a clippy run started without the component: $(cat "$work/go.log")"; fi
[ "$(tail -n 1 "$work/go.log")" = "rustup component add clippy" ] || bad "rust: a step ran after the failed component step: $(tail -n 3 "$work/go.log")"
