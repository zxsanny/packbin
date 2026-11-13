# Batch 01 report — loop 122 (hygiene)

Tasks: AZ-4277 (Dart, 1 pt), AZ-4278 (C++ sanitizer in CI, 3 pt). Parent, serial; no workers (two small tasks, the C++ one shares `cpp/build`).

## Task results

| task | status | proof |
|------|--------|-------|
| AZ-4277 | done | AC-1: `_bestBuild` times three builds of fresh fields against `LoadBound(300 ms)`. AC-2: a scratch copy of `dart/lib/src/checks.dart` with a quadratic `_followers` fails both cases (10,272 ms and 14,698 ms against 300 ms). Alone: 3 of 3 passes at host load 14 to 24. AC-3 (pool runs): step 11 |
| AZ-4278 | done | The sanitizer build is a step of the `cpp` suite (the 20-job limit of `publish-jobs-layout.py` and its nine-name suites matrix rule out a job of its own): `run-suite.sh cpp` with `PACKBIN_CPP_SANITIZER=1` (compose `cpp` service) installs Debian `clang-19` + `libclang-rt-19-dev` (pin `clang==19`) and runs `timeout 600 make -C cpp CXX=clang++-19 sanitizer-test`. AC-2: a planted heap overflow in a scratch copy fails it (`AddressSanitizer: heap-buffer-overflow`, exit 2). Self-test C1 in `run-suite.test.sh` (flag on, failing build, flag off) passes; two mutants of `run-suite.sh` (flag ignored, no time limit) are caught. AC-1 (three green CI runs): loop close and later |

## Found by the first real run (fixed)

- Debian clang 19 refuses the fold over 302 nodes of the 300-member `when` test (`-fbracket-depth` default 256; Apple clang allows it): `SAN_FLAGS` gets `-fbracket-depth=512`.
- UBSan: `memcpy` and `memcmp` from an empty vector's null `data()` in `cpp/tests/core/ecc_percent_host_tests.cpp` (lines 139, 149); Apple clang on the Mac does not report them. Guarded; a recover-mode run then showed no other report.

## Review

`/code-review` high: PASS_WITH_WARNINGS, 5 findings. Fixed: apt retries (`Acquire::Retries=3`), a message when the clang pin is missing. No change: the vectors test already guards its `memcpy`. Carried (discoveries below): the floating `gcc:16` base for `clang-19`; the clang fold-depth limit for library users.

## Discovered during implementation

| spec ref | discovery | proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AZ-4278 Design | `test.yml` is at the 20-job limit; the sanitizer is a suite step, not a job | spec revised at implement | clear |
| AZ-4278 | `include/packbin/table.hpp:266` sums node sizes with a fold expression; upstream clang's default nesting limit 256 refuses a `when` of 255+ members in a user's own build (only the test build has `-fbracket-depth`) | hygiene entry (Low): replace the fold with a constexpr loop, or document the limit | clear |
| AZ-4278 | `clang-19` exists only while `gcc:16` stays on Debian trixie; the tag floats | hygiene entry (Low): note in the pin comment; bump the pin when the base moves | clear |

## Tests

Dart cost test 3/3 alone; `run-suite.test.sh` all checks passed; `publish-pins.test.sh` run alone tests nothing (the gate sources it); cpp suite in its container: plain step green, sanitizer step green after the fixes (recover-mode run). Step 11 (`scripts/loop-tests.sh --jobs 4`, 13 stages, at load 25 to 154): typescript, csharp, python, rust, scaffold (2,018 s at that load), cpp-embedded-arm, rust-embedded pass; java, dart, go, cpp, swift fail in the pool during the load spike and container DNS loss (go: `proxy.golang.org: no such host`; cpp: apt could not reach Debian, so `clang-19` not found; java, dart, swift: wall-clock bounds) and pass on the serial retry (cpp 198 s with the sanitizer step 110 s); publish-gate failed once on `unexpected tool: clang` (the pin-name list of `publish-pins.test.sh`, fixed) and passed alone (389 s; vcpkg NOT RUN, N2).
