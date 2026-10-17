# Loop 34 scenarios — CI speed 5 (AZ-2627)

Fit walk of `new-task` Step 4.7 (5 points: up to 8 rows). All rows `confirmed` (silent proceed); the owner answered the scope (D1 to D4) and the C3 design (cache plus ccache) in two questions (`problem.md`).

## Fit (today → after)

| Area | Today | After | Who depends on today | Collision |
|------|-------|-------|----------------------|-----------|
| `suites` matrix | one job per language, Swift in three parts (11 jobs) | short suites share a job (at most 20 jobs in the workflow) | `publish-jobs.test.sh` (each language exactly one matrix entry, keys `lang` and `part` only, `SUITE` from `matrix.lang`) | the rule and its mutants change (card 1) |
| Swift suite build output | in the container's `/tmp`, gone after each job | in CI a host directory restored and saved by `actions/cache`, C compiles through ccache | `docker-compose.test.yml` comment (output stays out of the mounted tree), `run-suite-swift.test.sh` | the Mac must keep today's behavior (card 3) |
| ring Swift driver build | `ring-swift.sh` builds into `/tmp/packbin-ring-swift` as the runner's user in `swift:6.3.3` | the scratch dir restored and saved by `actions/cache`, C compiles through ccache | `ring-wiring-swift.test.sh` (the build line), `ring-prepare.sh` (starts the build after the swift pull), the stamp check in `ring-swift.sh` | ccache install needs root in a container that runs as the caller (card 2) |
| timing notices | seconds per step | plus the cache state and the ccache hits and misses | the metrics report reads them | none |

**Card 1 — merged suite jobs.** Today each language is its own job, and the guard checks exactly that. Options: A a matrix entry may name several languages, the step runs each in turn, keeps going after a failure and fails at the end naming the failed ones, and the guard counts each language once across all entries; B a separate job for the short suites outside the matrix. Recommended A (auto-applied): one job shape, one guard rule. Resolved.

**Card 2 — ccache in the ring's container.** The ring builds as the runner's user so its binaries belong to the runner, but installing ccache needs root. Options: A install as root at the start of the container, then build as the caller; B build as root and hand the files back afterwards; C no ccache in the ring (only the restored Swift modules help). Recommended A (auto-applied): the files are owned right from the start, and the ring gains the C part. Resolved.

**Card 3 — the Mac's runs.** `scripts/loop-tests.sh` runs the same compose services on the owner's Mac. Options: A ccache and the kept build output only when CI sets them (default off: the Mac's runs stay as today, no apt download); B the same on the Mac. Recommended A (auto-applied): the Mac stays the reference for a run from nothing. Resolved.

## Scenario matrix

| # | Actor / trigger | State | Proposed behavior | Status | AC |
|---|-----------------|-------|-------------------|--------|----|
| 1 | push to `dev` | no cache entry for the key (first push, or a dependency or image change) | every Swift build runs from nothing as today; tests pass; caches saved at the job's end | confirmed | AC-5, AC-7 |
| 2 | push to `dev` | cache hit, sources changed | the package's own targets rebuild, C compiles come from ccache, the swift-crypto Swift modules are reused; the tests run on the new code; no cache saved | confirmed | AC-1, AC-3, AC-4, AC-7 |
| 3 | push to `dev` | the ccache install fails (Ubuntu mirror down) | the build runs without ccache; the notice says ccache unavailable and why; the job's result is the tests' | confirmed | AC-6 |
| 4 | push to `dev` | the cache service fails on restore or save | restore failure: a miss (row 1); save failure: a warning, the job's result is the tests' | confirmed | AC-5 |
| 5 | two pushes close together | both runs miss the same key | both build from nothing; one save wins, the other warns that the entry exists | confirmed | AC-5 |
| 6 | push to `dev` | a merged suite job, one suite fails | the other suites of the job still run; the job fails naming the failed language | confirmed | AC-8 |
| 7 | editor | a language in two jobs, or none | `publish-jobs.test.sh` fails naming it | confirmed | AC-8, AC-10 |
| 8 | owner on the Mac | `scripts/loop-tests.sh` | as today: no ccache, no kept Swift build output | confirmed | AC-9 |
