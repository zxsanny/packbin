#!/usr/bin/env bash
# run-suite.sh cpp, the sanitizer step (AZ-4278, AZ-4280). Sourced by run-suite.test.sh, which defines bad, $here, $work,
# $present, $toolbin and $suite_sh (the script under test); it adds a fake apt-get and timeout to $toolbin, which log to $GO_LOG.
# shellcheck disable=SC2154

# C1. cpp with PACKBIN_CPP_SANITIZER=1 (the compose cpp service, AZ-4278): after the plain suite it installs Debian's
# clang of the pinned major and runs the sanitizer target with that clang under a 10-minute limit; without the flag it
# does neither; a failing sanitizer build fails the suite. Fake apt-get and timeout log their arguments.
cp "$here/tool-pin.sh" "$here/tool-pins.txt" "$present/.github/workflows/"
clang_pin="$(bash "$here/tool-pin.sh" clang)"
printf '#!/bin/sh\necho "apt-get $*" >> "$GO_LOG"\n[ -z "${FAKE_APT_FAIL:-}" ] || exit 100\n' > "$toolbin/apt-get"
printf '#!/bin/sh\necho "timeout $1" >> "$GO_LOG"\nshift\nexec "$@"\n' > "$toolbin/timeout"
chmod +x "$toolbin/apt-get" "$toolbin/timeout"
cpp_run() {
  rm -f "$work/bare.rows"; : > "$work/go.log"
  env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
    PATH="$toolbin:$PATH" "$@" perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" cpp </dev/null >/dev/null 2>&1
}
cpp_run PACKBIN_CPP_SANITIZER=1; code=$?
[ "$code" -eq 0 ] || bad "cpp sanitizer: the suite failed with every tool passing (exit $code): $(cat "$work/go.log")"
grep -q "^apt-get .*install .*clang-$clang_pin libclang-rt-$clang_pin-dev" "$work/go.log" \
  || bad "cpp sanitizer: clang-$clang_pin and its runtimes are not installed: $(cat "$work/go.log")"
grep -A1 '^timeout 600$' "$work/go.log" | grep -q "^make -C $present/cpp CXX=clang++-$clang_pin sanitizer-test$" \
  || bad "cpp sanitizer: the sanitizer target does not run with clang++-$clang_pin under a 600 s limit: $(cat "$work/go.log")"
[ "$(head -n 1 "$work/go.log")" = "make -C $present/cpp test" ] \
  || bad "cpp sanitizer: the plain suite does not run first: $(cat "$work/go.log")"
cpp_run PACKBIN_CPP_SANITIZER=1 FAKE_FAIL_ON="-C $present/cpp CXX=clang++-$clang_pin sanitizer-test"; code=$?
[ "$code" -ne 0 ] || bad "cpp sanitizer: a failing sanitizer build passed"
grep -Eqx "report-row cpp cpp suite [0-9]+ FAIL suite failed" "$work/bare.rows" \
  || bad "cpp sanitizer: a failing sanitizer build has no FAIL row: $(cat "$work/bare.rows" 2>&1)"
# AZ-4280: a failed install fails the suite with one line naming the pin to move and the image's Debian release; the
# line is absent when the install passes.
: > "$work/go.log"
out="$(env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
  PATH="$toolbin:$PATH" PACKBIN_CPP_SANITIZER=1 FAKE_APT_FAIL=1 perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" cpp </dev/null 2>&1)"; code=$?
[ "$code" -ne 0 ] || bad "cpp sanitizer: a failed clang install passed"
case "$out" in *"clang-$clang_pin is not installable on Debian "*"move clang==$clang_pin in .github/workflows/tool-pins.txt"*) ;;
  *) bad "cpp sanitizer: a failed install does not name the pin to move: $out" ;; esac
grep -q 'sanitizer-test' "$work/go.log" && bad "cpp sanitizer: the sanitizer build ran after a failed install"
out="$(env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
  PATH="$toolbin:$PATH" PACKBIN_CPP_SANITIZER=1 perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" cpp </dev/null 2>&1)"
case "$out" in *"is not installable"*) bad "cpp sanitizer: the install failure line shows after a good install: $out" ;; esac
cpp_run PACKBIN_CPP_SANITIZER=; code=$?
[ "$code" -eq 0 ] || bad "cpp: the suite without the sanitizer flag failed (exit $code)"
grep -Eq 'apt-get|sanitizer-test' "$work/go.log" && bad "cpp: the sanitizer step ran without its flag: $(cat "$work/go.log")"
