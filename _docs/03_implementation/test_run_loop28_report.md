# Test run — loop 28 (step 11)

Date: 2026-10-15. Commit `8d4f1a8`. One run: `scripts/loop-tests.sh --all` (host load 7 to 34 from other projects; Python 3.14 and `PACKBIN_CXX_SYSROOT` per `AGENT_GOTCHAS.md`). Logs in the run's temp directory.

SUITE: 13 specified / 13 executed / 0 not-run — PASS (inside the gate: vcpkg supports check and vcpkg consumer check NOT RUN, no vcpkg tool on this Mac, as before)

| Stage | Result | Time |
|-------|--------|------|
| typescript | PASS | 18 s |
| csharp | PASS | 57 s |
| python | PASS | 65 s |
| rust | PASS | 32 s |
| java | PASS | 21 s |
| cpp | PASS first time, no serial retry (loop 27: failed in the pool) | 42 s |
| go | PASS | 134 s |
| scaffold | PASS (incl. `loop-tests.test.sh` check 15, `ring-wiring`, `run-suite`, `report-row`) | 214 s |
| swift | PASS | 388 s |
| cpp-embedded-arm | PASS | 9 s |
| ring | PASS | 53 s |
| ac10 | PASS | 4 s |
| publish-gate | PASS (includes `publish-jobs.test.sh` 13 mutants rejected, `publish-timing.selftest.sh`) | 1 060 s |

Total 1 618 s. Exit 0. Every stage ran (all stamps were stale), so this is a full run, not a selection.

## Publish gate timings (AZ-2563, SP-5): 14 lines + total

| Check group | Seconds | Share |
|-------------|--------:|------:|
| swift | 284 | 27 % |
| readonly | 263 | 25 % |
| phases | 251 | 24 % |
| gate | 191 | 18 % |
| pins | 33 | 3 % |
| go | 14 | 1 % |
| vcpkg | 10 | 1 % |
| npm | 6 | 1 % |
| registry | 2 | — |
| crates-token | 1 | — |
| position | 1 | — |
| workflow | 3 | — |
| static, manifest | 0 | — |
| total | 1 059 | 100 % |

Four groups (swift, readonly, phases, gate) are 989 s, 93 % of the gate: those are where a next loop cuts. The earlier "about 750 s unattributed" is now attributed.

## CI

Not run yet: SP-1 and SP-2 (five jobs green, at most 25 minutes) need a pushed `dev` commit and the owner's go.

CI-parity: PASS (the stages `test.yml` runs; the new `suites` and `publish-gate` jobs run the same commands as the old steps).
