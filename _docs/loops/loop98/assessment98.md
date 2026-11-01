# Feature assessment - loop 98

loop: 98
feature: percent-docs-and-embedded-run
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-11-01
**Implement pass**: batch 01 (commit 279ef54), report `_docs/03_implementation/batch_01_loop98_report.md`
**Verdict**: COMPLETE - 9 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A Swift reader finds the percentage next to the count | covered | AZ-3524 AC-1; blackbox symbol check (0 missing); `Packbin.md` section naming `Limits.swift` `withLimits(parityPercent:)` and `Scheme.parityPercent` | intake |
| S2 | A Go reader finds the three names with `go doc` | covered | AZ-3524 AC-2; `go doc` printed `WithParityPercent`, `ParityPercent`, `MaxParityPercent`; `go/doc.go`, `go/ecc_percent.go` | intake |
| S3 | The pages equal the README | covered | AZ-3524 AC-3; read side by side, one real difference found and fixed in the README (`TooMany` to `TooLong` for Go, `.tooMany` to `.tooLong` for Swift) | intake |
| S4 | The C++ vector runner runs a percentage test on M3 and M33F | covered | AZ-3525 AC-1, AC-2; `ecc_percent_tests.cpp` 25 of 25 checks on both; `codec_ecc.hpp` | intake |
| S5 | p = 100, p = 1 and the 32 cap | covered | AZ-3525 AC-1; rows `encp.zeros.p100/p1`, `encp.pos.*` in `ecc_percent_tests.cpp` | intake |
| S6 | p = 101 on the device image | covered | AZ-3525 AC-1; SchemeInvalid case in `ecc_percent_tests.cpp` | intake |
| S7 | Damage with a limit above n / 2 | covered | AZ-3525 AC-1 and AZ-3526 AC-1; `fixp`/`badp` rows; Rust `percent_roundtrip` on `rust-m33f` | intake |
| S8 | The Rust count round trip keeps running | covered | AZ-3526 AC-3; `count_roundtrip` kept, EXTRA_RESULT 0 | intake |
| S9 | Same bytes on M3 and M33F | covered | AZ-3525 AC-2; `arm.sh` `cmp` of 12 packets; the Rust probe has one row since loop 94 (M4F dropped), so there is nothing to compare there | intake |
| S10 | Rounding changed to floor turns a run red | covered (both) | AZ-3525 AC-3 and AZ-3526 AC-3; mutation runs M3, M33F, s390x red and `rust-m33f` EXTRA_RESULT 350 | intake |
| S11 | A pin crossed needs the owner's yes | covered | the ecc pin crossed by 856 B, asked, owner agreed, re-pinned and recorded in `limits-m33f.txt` and AGENT_GOTCHAS | intake |
| S12 | No concurrent actor or permission in docs or a bare-metal test | out-of-scope | scenarios.md S12 (library, no actor) | intake |

Candidates from the batch report, not scenarios of this feature (no verdict effect):

| id | candidate | status | evidence |
|----|-----------|--------|----------|
| D1 | Go `WithLimits(Limits)` keeps the percentage | out-of-scope | unchanged behavior outside this loop; `go/limits.go:53` copies the whole scheme |
| D2 | s390x does not compare percentage packets with M3 | out-of-scope | not in any AC; the runner prints identical packets (read from the log) |
| D3 | Swift example in the page not compiled | out-of-scope | Swift not installed here; every call of the example exists in `Unpack.swift` / tests; carried as the open Low concern |

### Not walked

- A DocC build of the page (needs Swift on the host); `go vet` of the Go package (needs the network for `x/crypto`).
