#!/usr/bin/env bash
# Loop 114 smoke (AZ-4237, the C++ ECC test declares the 17-byte buffer it packs into): one paste, PASS/FAIL per step.
# Run from the repository root. Short loop: one test line, no library change; the C++ suites are the whole test scope.
set -u
fail=0
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke114-failed-logs"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
sr="$(xcrun --show-sdk-path)"
s1() { # the test declares out[17] for its capacity-17 pack
  sed -n '/^void pack_into_a_small_buffer/,/^}/p' cpp/tests/core/ecc_api_tests.cpp > "$work/fn.txt"
  grep -q 'std::uint8_t out\[17\];' "$work/fn.txt" && grep -q 'out, 17)' "$work/fn.txt" && echo "out[17], capacity 17"
}
s2() { # ASan + UBSan host suite in a copy of the tracked tree: no sanitizer report, and no failing check other than
  # a wall-clock bound ("within ..."): the load factor's reference loop is integer work ASan does not slow, the timed
  # code is memory work it does, so a sanitizer build misses 1 s bounds by a few ms (queue item
  # cpp-wall-clock-bounds-under-sanitizers). The plain builds of steps 3 and 4 hold every bound.
  local c="$work/asan"
  mkdir -p "$c" && git ls-files cpp fixtures scripts | rsync -a --files-from=- . "$c/" || return 1
  limit 900 make -s -C "$c/cpp" build/packbin_tests CXX=clang++ FRAME_LIMIT=1000000 \
    CXXFLAGS="-std=c++17 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all -Wall -Wextra -Werror -Wframe-larger-than=1000000 -Iinclude -isysroot $sr -I$sr/usr/include/c++/v1" \
    < /dev/null > "$work/asan-build.log" 2>&1 || { tail -5 "$work/asan-build.log"; return 1; }
  (cd "$c/cpp" && limit 900 ./build/packbin_tests < /dev/null > "$work/asan-run.log" 2>&1); local rc=$?
  local reports other timing
  reports="$(grep -c -E 'AddressSanitizer|runtime error' "$work/asan-run.log")"
  timing="$(grep -c -E '^FAIL: .*within .*load factor' "$work/asan-run.log")"
  other="$(grep '^FAIL: ' "$work/asan-run.log" | grep -c -v -E 'within .*load factor')"
  echo "exit $rc, sanitizer reports $reports, other failing checks $other, wall-clock bounds missed $timing"
  grep -E '^FAIL: .*within .*load factor' "$work/asan-run.log"
  [ "$reports" -eq 0 ] && [ "$other" -eq 0 ] || return 1
  [ "$rc" -eq 0 ] && grep -q '^all tests passed$' "$work/asan-run.log" && return 0
  [ "$timing" -gt 0 ]
}
s3() { # Apple clang: make test
  make -s -C cpp clean < /dev/null || return 1
  PACKBIN_CXX_SYSROOT="$sr" limit 900 make -C cpp test < /dev/null > "$work/host.log" 2>&1 || { tail -8 "$work/host.log"; return 1; }
  make -s -C cpp clean < /dev/null; echo "host make test: exit 0"
}
s4() { # GCC 16 in the CI image: make test (cleaned inside the container)
  limit 900 docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 sh -c 'make -s clean && make test && make -s clean' \
    < /dev/null > "$work/gcc.log" 2>&1 || { tail -8 "$work/gcc.log"; return 1; }
  echo "gcc:16 make test: exit 0"
}
s5() { # the queue item left the backlog and the loop claims it
  [ ! -e _docs/02_tasks/backlog/cpp-ecc-api-test-out-buffer.md ] &&
    grep -q '^loop: 114$' _docs/02_task_plans/cpp-ecc-api-test-out-buffer/problem.md && echo "claimed by loop 114"
}
step "1. the test declares out[17] for capacity 17" s1
step "2. ASan + UBSan host suite: 0 reports, no failing check but a wall-clock bound" s2
step "3. Apple clang make -C cpp test" s3
step "4. gcc:16 make test" s4
step "5. the queue item is claimed by loop 114" s5
if [ "$fail" -eq 0 ]; then echo "smoke 114: 5/5 PASS"; rm -rf "$work"; else rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke 114: FAIL (logs in $keep)"; fi
exit "$fail"
