# Test Run — loop 22

**Date**: 2026-10-12 to 2026-10-13 (the run spanned a night because the host was swapping)
**Commit under test**: `1dceae6` (loop 22 implementation `04a8cd9` plus the review fixes); the tree was clean apart from `_docs/` reports. Docker containers ran from a `git archive HEAD` export.
**Mode**: functional. One total run for the loop, by the owner's direction (2026-10-06): workers ran only their own package suite; no Docker run per batch. Script: stage by stage, a result line per stage, a 30 s heartbeat. Wall time hours, not minutes (see Host condition). The agent smoke script (`_docs/loops/loop22/smoke22.md`, 13 steps) then re-ran the suites at `4140f24` on a quiet host.

```
TEST RESULTS (step 11, first pass at 1dceae6): 4 517 passed, 2 failed (both timing tests under host load: csharp 1839 of 1840 on net10.0, python 1105 of 1106; the C# netstandard2.0 run did not start after the first failure and was run in the smoke gate); typescript 917 and rust 656 passed in full; java and C++ counted below
  csharp 1839 passed, 1 failed (Ac10TimingTests, 4 676 ms against a 1 000 ms bound); typescript 917 passed; python 1105 passed, 1 failed (test_position.py::test_nfr_round_trips, a timing assertion); rust 656 passed (489 lib + integration binaries), 0 failed; java PackbinTest checks 2252, "All tests passed"; C++ "all tests passed"
TEST RESULTS (smoke re-run at 4140f24, quiet host): csharp 1840 on net10.0 and 1840 on netstandard2.0, typescript 917, python 1106, rust 489 lib (656 total across binaries), java 2252, C++ pass, ARM pass, ring pass, AC-10 pass; 13/13 steps
SUITE: specified 8 / executed 7 / not-run 1 suite (cpp-embedded-esp stopped by hand), plus the scaffold checks, the cross-language ring and the publish gate executed
```

## Verdict: PARTIAL

`failed = 0` at the commit under test once the three timing tests are re-run on a quiet host (they pass there: smoke steps 3, 7 and 13). Not run on this host:

- `cpp-embedded-esp` (ESP32-S3, ESP32-C3, ESP-IDF example, Arduino-ESP32, Pico): started, stopped by hand at 928 of 980 build steps of its first target after about 2 hours because the host was swapping and the ring and publish gate were queued behind it. No verdict. The CI `embedded` job runs it on the push of `dev`. The Pico example does not build on this host in any case (PlatformIO has no linux arm64 toolchain), as in loops 19 to 21.
- Inside the publish gate: the vcpkg supports check and the vcpkg consumer check (no vcpkg tool on the host), as in earlier loops.

## Suites (first pass, `1dceae6`)

| Suite / check | Result | Detail |
|---------------|--------|--------|
| `scaffold-golden` stage | killed by the stage alarm (rc 142) during a laptop sleep, in `cases.test.sh` | re-run by hand afterwards: golden row, `report-row.test.sh`, `cases.test.sh` (56 s), `run-suite.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh`, all PASS; `check-cases.sh` printed `hostile cases ok: 65` in smoke step 2 |
| `tsc --noEmit --strict` | PASS | 2 s |
| csharp | 1 FAIL (timing) | 1839 passed; `Ac10TimingTests.Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond` 4 676 ms; passes in 4 s on the quiet host (smoke 13) |
| typescript | PASS | 917 passed, 40 s |
| python | 1 FAIL (timing) | 1105 passed in 74 s; `test_position.py::test_nfr_round_trips`; passes in smoke 7 (1106 in 30 s) |
| rust | PASS | 656 across 16 test binaries, 0 failed; 1 988 s wall under load |
| java | PASS | `PackbinTest checks: 2252`, scheme / field id / session tests |
| cpp (CI container, GCC 16, `-Wall -Wextra -Werror`) | PASS | `all tests passed` |
| embedded ARM (`cpp-embedded`) | PASS | `cpp-m4f` AC-5 flash **8152 B of 8192** (margin 40 B); deepest pack/unpack stack **456 B of 512** (margin 56 B); largest core frame 528 B; M0+ PASS; M3 QEMU 241 of 241 vectors; s390x 241 of 241; 1 071 s |
| embedded ESP (`cpp-embedded-esp`) | NOT RUN | stopped by hand, see Verdict |
| cross-language ring (`language-pair.sh`) | PASS | 11 296 s under load (83 s in smoke 12) |
| publish gate | PASS | 8 864 s, `publish gate: no failures`, NOT RUN: vcpkg supports check, vcpkg consumer check |

## Host condition

Load average 40 to 145 from the start of the run: Chrome, an unrelated test run of another project, the Docker VM holding about 6.8 GB of a 7 GB machine (5.5 GB of swap), and macOS scanning (`syspolicyd`, `mds`, XProtect) the thousands of short processes the ring starts. The idle numbers of loop 21 (ring 107 s, publish gate 745 s, whole run 1 297 s) are the reference; nothing in this loop's diff changes a runtime path of the ring.

## Failures found

None that survived a quiet re-run. The three timing tests that failed under load (C# `Ac10TimingTests`, Python `test_nfr_round_trips`, Rust `nfr_round_trips_under_one_second` during the worker runs) passed on the idle smoke run. The TypeScript memory test (`loop22-max-slots.test.ts`) passed with its loosened bound (535 MB; measured 353 MB).

## Reality gate

- The six suites run the real packers and unpackers through each package's public API in the CI containers; the ring runs the real packers and unpackers of every pair on the same bytes; the hostile set replays the 65 cases (10 new) through six loaders, each with standing wrong-rule tests.
- Every behavior change has a test that failed first on the previous code in the packages that report it (the review ran the 88c063f tests against the HEAD sources: TypeScript 19, Python 19, Rust 8 and C# 13 failures, all intended).
- Golden `4001000065cd1d00a3e1110100` and the route fixture are unchanged in all six packages.
- Accepted-row byte changes of the loop: none (review probes: a 142-row TypeScript grid, a 140-row Python grid and a 4 000-row Python repeat fuzz found no row that packed before and changed bytes).

## CI parity

`test.yml` steps: required files and golden row, report columns, hostile case file, suite runner, embedded harness, ring wiring, the six suites, publish gate (scaffold job); the `embedded` job; the `ring` job. All ran here except the ESP / Pico targets of the `embedded` job and the two vcpkg checks.

## Lessons from the run

- Check `uptime` and `sysctl vm.swapusage` before a total run; a swapping host makes the ring and the publish gate take hours and fails timing tests that pass in seconds when idle.
- A `perl alarm` stage timeout counts wall time across sleep, and the alarm survives `exec` into `docker compose`, which does not stop on it.
