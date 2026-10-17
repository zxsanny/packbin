# Feature assessment — loop 34

loop: 34
feature: ci-speed-5
rounds: 1
verdict: COMPLETE (every AC and scenario has code, a guard or test and a production path; AC-1 to AC-5 and AC-7 are measured on the `dev` runs and filled in at loop close)

FEATURE ASSESSMENT loop 34 round 1: COMPLETE — 19 covered / 2 out-of-scope / 0 gap-clear / 0 gap-unclear

| id | scenario | status | evidence |
|----|----------|--------|----------|
| AC-1 | CI wall, median of two primed `dev` runs at most 225 s | covered (CI measurement pending) | `test.yml` caches and merged suites; blackbox row: the two runs after the priming push |
| AC-2 | at most 20 jobs, each started within 15 s | covered (start offsets pending) | 20 jobs (`publish-jobs.test.sh` job count rule, mutant "more than 20 jobs") |
| AC-3 | four Swift builds hit by exact key; ccache at least 95 % hits; notice gives both | covered (CI hit rate pending) | cache steps (suites, ring); `run-suite.sh` cache line, `ring-prepare.sh` notice lines; S12b/c, ring-prepare row 1b; real Mac run: 372 of 372 hits after a restore |
| AC-4 | each Swift build under its loop 33 best | covered (CI seconds pending) | real Mac run: debug build 52 s then 9 s (own sources not refreshed there) |
| AC-5 | a miss builds as today and saves | covered (priming push pending) | no restore-keys; miss path = the old build plus ccache set-up; chown before the save; real Mac miss run passed |
| AC-6 | failed ccache install is best-effort and named | withdrawn (owner, 2026-10-17) | ccache removed in batch 2: CI recompiles no C file after a restore (run A) |
| AC-7 | key = build, image tag, manifests; no save on a hit; at most 3 GB | covered (size pending) | `publish-jobs.test.sh` and `ring-wiring-swift.test.sh` key rules with mutants; actions/cache saves only on a miss |
| AC-8 | each language in one job; a failed suite does not stop the others and is named | covered | suite step loop; `publish-jobs.test.sh` order rule, 9 mutants |
| AC-9 | Mac unchanged | covered | `PACKBIN_SWIFT_CACHE` set only by `test.yml`; S12a (no install, no CC, no line; compose does not set it); step 11 run |
| AC-10 | no check lost; guards pass; a mutant per changed rule | covered | 7 guards pass; 33 new guard mutants, 11 mutants of the new code (1 equivalent) |
| AC-11 | files at most 500 lines | covered | largest changed: `ring-wiring.test.sh` 500 (in place), `run-suite-swift.test.sh` 470 |
| S1 | first push, no cache entry | covered | AC-5 |
| S2 | hit, sources changed: own targets rebuild, C from ccache | covered | SwiftPM rebuilds after a checkout (fresh times); spike and real Mac run |
| S3 | apt mirror down | withdrawn | no apt download since batch 2 |
| S4 | cache service down | covered | actions/cache restore failure = miss (`cache-hit` not `true`); save failure is a warning |
| S5 | two pushes miss the same key | covered | actions/cache: the second save warns "already exists" |
| S6 | a merged job, one suite fails | covered | AC-8 |
| S7 | a language in two jobs or none | covered | AC-8 mutants |
| S8 | the Mac | covered | AC-9 |
| D1 | `publish.yml` calls `test.yml` on a tag | out-of-scope (decided) | no cache step on a tag ref (both guards hold the condition, mutants); a release test run builds from nothing |
| R5 | the ring's cache restore runs before its image pulls (review finding 5) | out-of-scope (owner, 2026-10-17) | skipped until the CI notices show the restore's seconds |

## Not walked

None beyond the rows above: the batch report's 8 discoveries are all `clear` and handled; the review's 6 findings are fixed or decided.

## Round 1 addendum (batch 2, 2026-10-17)

Run A showed ccache asked 0 times; the owner removed it. AC-3's ccache clause and AC-6 are withdrawn, S3 goes with them; every other row keeps its evidence (the cache steps, keys, notices and merged suites are unchanged). Verdict stays COMPLETE.
