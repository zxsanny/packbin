#!/usr/bin/env bash
# The cpp helpers of run-suite.sh (AZ-4288), sourced from its `cpp` case so that file stays under 500 lines,
# as run-suite-dart.sh is. The caller runs each step through `run`; nothing here reads its variables.
# shellcheck disable=SC2154

# Debian's clang $1 and its sanitizer runtimes, in the gcc image of the cpp suite (AZ-4278); a mirror that fails once is
# asked again. A failed install names the pin to move (AZ-4280): the gcc:16 tag floats, and a later Debian may not ship it.
cpp_clang_install() {
  apt-get -o Acquire::Retries=3 update -q && DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 install -y -q \
    --no-install-recommends "clang-$1" "libclang-rt-$1-dev" && return 0
  echo "run-suite: clang-$1 is not installable on Debian $(cat /etc/debian_version 2>&1); move clang==$1 in .github/workflows/tool-pins.txt to a major this image ships" >&2
  return 1
}
