---
kind: queue-item
order: 500
source: found in loop114 (AZ-4237 smoke: the ASan + UBSan host suite)
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# C++: wall-clock bounds in a sanitizer build of the host suite

## Problem
Under clang `-fsanitize=address,undefined` the C++ host suite reports no memory or UB error since AZ-4237, but the text speed check "AC-7 100,000 round trips within one second" fails in about one run of two (1.015 s against 1.012 s, 1.017 s against 1.004 s, loop 114, host load 9 to 50). `load_factor.hpp` scales a bound by an integer xorshift loop that ASan does not instrument, while the timed text code is memory work that ASan slows, so the factor does not see the sanitizer's cost. The plain Apple clang and GCC 16 builds hold the bound. This blocks running the host suite under ASan in CI, which the loop 113 security audit recommends (long term).

## Outcome
A sanitizer build of `build/packbin_tests` prints `all tests passed` on this Mac and on the CI runner, while the plain builds keep every wall-clock bound as it is.

## Code sections
`cpp/tests/core/load_factor.hpp` (the factor, `expect_within`), `cpp/tests/core/text_codec_host_tests.cpp:264`, and every other `expect_within` / `load_factor::bound` caller (`hostile_host_tests.cpp`, the ECC and text-repeat timing lines); `cpp/Makefile` if a sanitizer target is added.

## Acceptance checks
- A sanitizer build (`-fsanitize=address,undefined -fno-sanitize-recover=all`) passes 5 runs in a row on this Mac with no sanitizer report.
- `make -C cpp test` (Apple clang) and `gcc:16` `make test` pass, and a deliberately slowed timed section still fails the plain build (a check on a broken copy).

## Needs
none

## Constraints
Do not widen the bounds of the plain build. One way, to be chosen in the task: the timing checks print but do not assert when `__has_feature(address_sanitizer)` / `__SANITIZE_ADDRESS__` is set.
