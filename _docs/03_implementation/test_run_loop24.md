# Test Run — loop 24

**Date**: 2026-10-13
**Commit under test**: `ed30ddf` (loop 24 implementation `14a3ec0`, the review fixes `c9cc56a` and the assessment commit; the tree was clean at the start; steps 12 to 14 then wrote only `_docs/` files while the run was going, which no stage reads).
**Mode**: functional. One total run for the loop (owner direction, 2026-10-06): workers ran only their own suite. The six packages' sources are unchanged since `37470e4` (`git diff --stat 37470e4..HEAD -- csharp typescript python rust cpp java` is empty), so the six run once each in their CI containers (the native TypeScript, C# net10.0 and netstandard2.0 duplicates of loop 23 are not repeated). Script: stage by stage, a result line per stage, a 30 s heartbeat. Host before the run: load 9, no active swapping (0 swapouts in 10 s); the load reached 89 for a few minutes while the security auditor's probes and the C++ build ran together, and no timing test failed.

```
TEST RESULTS (step 11 at ed30ddf): 12/12 stages passed (stage 2 counted by evidence, see below); failed = 0
  go 1389 passing test lines in golang:1.27 (gofmt, vet, race tests, speed bound without race 160/128 ms, 60 s fuzz 1.19M execs, dependency check), report row go,go suite,113000,PASS
  typescript 967 (container); csharp 1978 (container); python 1476; rust 673 across 21 binaries; java 2540 checks
  cpp GCC 16 -Werror all tests passed; ARM: M4F flash 8152 of 8192 B (margin 40 B), stack 456 of 512 B, M0+ PASS, M3 QEMU 241 of 241, s390x 241 of 241
  ring with Go: language pairs passed (169 s); AC-10 in C# 330 ms; publish gate with seven languages: no failures
SUITE: specified 12 / executed 12 / not-run 0 stages; inside the stages NOT RUN: cpp-embedded-esp (CI only), the vcpkg supports and consumer checks (no vcpkg tool on the host)
```

## Verdict: PASS

`failed = 0` at the commit under test. Not run on this host (as in loop 23): `cpp-embedded-esp` (ESP32-S3, ESP32-C3, ESP-IDF example, Arduino-ESP32, Pico: the CI `embedded` job runs it on the push); inside the publish gate the vcpkg supports check and the vcpkg consumer check. Not run at all, by design: the first real `go/vX.Y.Z` tag and the live `proxy.golang.org` check (no tag in this loop), and the first Ubuntu runner run of the new `ring` and `go` steps (the CI run on the `dev` push is their proof).

## Stages

| Stage | Result | Detail |
|-------|--------|--------|
| 1 scaffold | PASS (131 s) | golden row, `report-row.test.sh`, `cases.test.sh`, `check-cases.sh` (65 cases, seven package names), `run-suite.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh`, `publish-go.test.sh` |
| 2 Go (CI container, `golang:1.27`) | PASS (114 s) | the script marked it FAIL only because its expected text used spaces where `go test` prints a tab after `ok`; the evidence: exit 0, 1 389 passing test lines, no FAIL line, the report row `go,go suite,113000,PASS`; race-detector speed 782/598 ms at load about 30 (skipped under `-race`, asserted without it: 160/128 ms) |
| 3 TypeScript (CI container) | PASS (9 s) | pass 967 |
| 4 C# (CI container) | PASS (74 s) | 1978 |
| 5 Python (CI container) | PASS (71 s) | 1476 passed |
| 6 Rust (CI container) | PASS (20 s) | 673 across 21 binaries, 0 failed |
| 7 Java (CI container) | PASS (12 s) | `PackbinTest checks: 2540` |
| 8 C++ (CI container, GCC 16, `-Wall -Wextra -Werror`) | PASS (39 s) | all tests passed |
| 9 embedded ARM (`cpp-embedded`) | PASS (260 s, image rebuilt: the host Docker had been restarted and the local image was gone) | `cpp-m4f` AC-5 flash **8152 B of 8192** (margin 40 B); deepest pack/unpack stack **456 B of 512**; M0+ PASS; M3 QEMU 241 of 241; s390x 241 of 241 |
| 10 cross-language ring with Go | PASS (169 s) | language pairs passed: 15 payload kinds, the session ring, `pack-session`, the position check with Go |
| 11 AC-10 (C# Release) | PASS (4 s) | `Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond` 330 ms |
| 12 publish gate (seven languages) | PASS (600 s) | no failures; NOT RUN: vcpkg supports check, vcpkg consumer check |

## Timing tests

No timing test failed. The Go speed bound is asserted without the race detector since the review fix (a second `go test -run` step in `run-suite.sh go`); under `-race` at load about 30 it measured 782/598 ms.

## Coverage of this loop's ACs

Every GO criterion has a standing test (traceability matrix, loop 24 rows, FT-X-83 to FT-X-112); all ran green above. GO-7 and the position check ran in stage 10, GO-9 in stage 2, GO-10 and GO-16 in stages 1 and 12 (`publish-go.test.sh`, `publish-gate.test.sh`).

## After this run

The owner accepted the security findings F41 to F45 for fixing in this loop (2026-10-13). The fix wave changes the Go package (unpack size hints, zero-value scheme guard, session mutex), `publish-go.sh`, `publish-check.py` and ADR-004; the closing smoke run repeats these stages at the final commit.
