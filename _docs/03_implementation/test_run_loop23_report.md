# Test Run — loop 23

**Date**: 2026-10-13
**Commit under test**: `807e718` (loop 23 implementation `3c602ff` plus the review fixes); the tree held only uncommitted `_docs/` reports (step 12/13/14 docs). Docker stages ran from the repo checkout.
**Mode**: functional. One total run for the loop (owner direction, 2026-10-06): workers ran only their own package suite. Script: stage by stage, a result line per stage, a 30 s heartbeat. Host before the run: load about 10, swap 4.1 GB used but no active swapping (0 swapouts in 10 s, 59 % memory free); load 4 to 27 during the run (Spotlight indexing, the security auditor's probes and another project's `dotnet run`).

```
TEST RESULTS (step 11 at 807e718): 14/14 stages passed; failed = 0
  typescript 967 (native) and 967 (container); strict tsc clean
  csharp 1978 on net10.0, 1978 on netstandard2.0, 1978 in the container
  python 1476 (container); rust 673 across 21 binaries (container); java 2540 checks (container)
  cpp GCC 16 -Werror all tests passed; ARM: M4F flash 8152 of 8192 B, stack 456 of 512 B, M0+ PASS, M3 QEMU 241 of 241, s390x 241 of 241
  ring: language pairs passed (93 s); AC-10 411 ms; publish gate: no failures
SUITE: specified 8 / executed 7 / not-run 1 suite (cpp-embedded-esp: CI only), plus scaffold checks, ring, AC-10 and the publish gate executed
```

## Verdict: PASS

`failed = 0` at the commit under test. Not run on this host:

- `cpp-embedded-esp` (ESP32-S3, ESP32-C3, ESP-IDF example, Arduino-ESP32, Pico): the CI `embedded` job runs it on the push (PlatformIO has no linux arm64 toolchain for the Pico target; the amd64 emulation takes hours here, loop 22). Not a pass.
- Inside the publish gate: the vcpkg supports check and the vcpkg consumer check (no vcpkg tool on the host), as in earlier loops.

## Suites

| Stage | Result | Detail |
|-------|--------|--------|
| 1 scaffold | PASS (66 s) | golden row, `report-row.test.sh`, `cases.test.sh`, `check-cases.sh` (65 cases), `run-suite.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh` |
| 2 TypeScript native + strict tsc | PASS (6 s) | pass 967, fail 0 |
| 3 C# net10.0 | PASS (14 s) | 1978 |
| 4 C# netstandard2.0 | PASS (14 s) | 1978 |
| 5 Python (CI container) | PASS (54 s) | 1476 passed in 47.8 s (includes the AZ-2435 raised-limit tests) |
| 6 Rust (CI container) | PASS (38 s) | 673 across 21 binaries, 0 failed |
| 7 Java (CI container) | PASS (10 s) | `PackbinTest checks: 2540` |
| 8 C# (CI container) | PASS (43 s) | 1978 |
| 9 TypeScript (CI container) | PASS (9 s) | pass 967 |
| 10 C++ (CI container, GCC 16, `-Wall -Wextra -Werror`) | PASS (23 s) | all tests passed |
| 11 embedded ARM (`cpp-embedded`) | PASS (8 s, warm cache) | `cpp-m4f` AC-5 flash **8152 B of 8192** (margin 40 B); deepest pack/unpack stack **456 B of 512** (margin 56 B); M0+ PASS; M3 QEMU 241 of 241; s390x 241 of 241 |
| 12 cross-language ring (`language-pair.sh`) | PASS (93 s) | language pairs passed |
| 13 AC-10 (Release) | PASS (5 s) | `Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond` 411 ms |
| 14 publish gate | PASS (780 s) | no failures; NOT RUN: vcpkg supports check, vcpkg consumer check |

## Timing tests

No timing test failed (loop 22 lost three to host load). Review23 Low 6 (heavy AZ-2435 tests) is judged here: Python's suite took 47.8 s in the container and Rust's 38 s; no marker needed now.

## Coverage of this loop's ACs

Every AC of AZ-2431 to AZ-2437 has a standing test in its package suite (traceability matrix, loop 23 rows, FT-X-75 to FT-X-82); all ran green above.
