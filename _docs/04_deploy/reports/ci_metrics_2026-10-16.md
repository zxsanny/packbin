# CI and test timing metrics — 2026-10-16

Sources: GitHub public API (jobs, steps, check-run annotations), the job logs of `test.yml` run 38903922126 (`suites`) and `publish.yml` run 38894017715 (`publish`), the loop 28 and 29 step 11 logs on the owner's Mac. Runner speed varies by about 1.5x between runs of the same code, so read ranges, not points.

## 1. test.yml (every push): last runs

| Run | Commit | Wall | scaffold | suites | publish-gate | embedded | ring |
|-----|--------|-----:|---------:|-------:|-------------:|---------:|-----:|
| 38903922126 | 27222bd | 980 s | 63 | 896 | 977 | 350 | 290 |
| 38899409639 | 84f0bbc | 1 095 s | 62 | 1 026 | 1 091 | 370 | 290 |
| 38893878411 | 51ee43b | 1 049 s | | | | | |
| 38891164077 / 38891168328 | 2cade74 | 1 074 / 1 015 s | 56 / 54 | 1 071 / 874 | 825 / 1 011 | 296 / 354 | 284 / 271 |
| 38888934994 | 1ce48a2 | 892 s | 61 | 888 | 689 | 357 | 272 |
| 38736693696 (loop 28) | 182fbba | 1 396 s | 50 | 876 | 1 392 | 352 | 304 |

The wall time is the longer of `suites` and `publish-gate` (15 to 18 minutes); the other three jobs are 1 to 6 minutes.

## 2. `suites` job (run 38903922126, 892 s): per language, from the runner log

Sum of timed steps 725 s; 167 s is image pulls and container start-up. The eight suites run one after another.

| Language | Timed steps | Largest steps |
|----------|------------:|---------------|
| swift | 419 s | `swift_speed` 87, `swift_fuzz` 70 (60 s fixed fuzz time), three `swift build` 63 / 66 / 67, `swift_sanitized` 31, `swift test` 29 |
| go | 121 s | `go_fuzz` 73 (60 s fixed fuzz time), `go test -race` 36, `go vet` 8 |
| python | 60 s | pytest 1 494 tests, 60 |
| csharp | 52 s | `dotnet test` 28 + 24 (second target framework) |
| rust | 27 s | |
| cpp | 24 s | |
| typescript | 12 s | |
| java | 10 s | |

Mac (loop 28 step 11, one stage each): swift 388, go 134, python 65, csharp 57, cpp 42, rust 32, java 21, typescript 18.

## 3. `publish-gate` job (run 38903922126, 977 s): per group, from the annotation

pull images 60 to 99 s, then the gate step (911 s on this run, 593 s on run 38888934994 with the same code):

| Group | This run | Run 38888934994 | Mac (step 11, 754 s total) |
|-------|---------:|----------------:|---------------------------:|
| readonly | 302 | 201 | |
| phases | 216 | 158 | |
| swift | 189 | 116 | |
| gate | 112 | 74 | |
| workflow | 31 | 3 | |
| vcpkg | 25 | 11 | |
| pins | 22 | 20 | |
| the other seven | 14 | 10 | |
| total | 911 | 593 | 754 |

## 4. Tag publish run (v0.3.0, run 38894017715): 58 minutes in total

| Phase | Time |
|-------|-----:|
| `test` job (the whole `test.yml` again; `publish-gate` 784 s was the longest) | 13 min |
| `publish` job: golden-bytes gate over 8 languages | 204 s |
| builds of all 9 targets | 33 s |
| uploads (NuGet, npm, PyPI, crates.io, vcpkg, Maven request) | 20 s |
| waiting for Maven Central to reach PUBLISHED (polled every 15 s, VALIDATING at 266 s, PUBLISHING from 281 s, PUBLISHED at 1 453 s) | 1 187 s (44 %) |
| Go tag pushed, then `proxy.golang.org` polled every 30 s: 38 misses, answered on try 39 | 1 158 s (43 %) |
| Swift consumer resolve and build | 69 s |
| total `publish` job | 2 690 s (45 min) |

The Maven wait and the Go wait are serial but independent of each other.

## 5. Ways to reduce, with the numbers above

| # | Change | Saves | Cost / risk |
|---|--------|-------|-------------|
| T1 | Tag run skips the repeated `test` when the commit already has a green run (done: commit 84f0bbc, not yet seen on a tag) | 13 min per tag | none beyond the new guard |
| T2 | Push the Go tag and run the Swift check while Maven Central is still publishing; keep "no Go tag after a registry rejects the upload" by pushing it once Maven reports PUBLISHING (validated) | up to 20 min per tag (45 to about 25 min publish job) | a Maven failure after validation would leave a Go tag; owner decision |
| T3 | Do not hold the job for the Go proxy: verify it in a separate non-blocking job, or warm the proxy once after a pause; find why a first-time tag needs 19 minutes | up to 19 min of run time | the run is green before the proxy serves the tag |
| T4 | The golden-bytes gate (204 s) pulls images the `publish-gate` job already pulled; cache or overlap | about 1 to 2 min | small |
| C1 | `suites` as a matrix, one job per language (swift 419 s is the longest; two swift jobs make about 250 s) | `suites` 896 s to 250 to 470 s | more jobs; public repo, runner minutes are free |
| C2 | `publish-gate` in 3 parallel jobs (readonly 302 s; phases 216 + gate 112 + pins 22 s; swift 189 + vcpkg + the rest) | gate 977 s to about 400 s | guards that read `test.yml` follow (as in loop 28) |
| C1 + C2 | together: the wall becomes embedded (350 s) and ring (290 s) | test.yml 15 to 18 min to about 7 min | do both: either alone changes nothing, the other is the long pole |
| C3 | Cache the Swift build and the docker images between runs | unknown (measure first) | cache keys, invalidation |
| C4 | Split the embedded job (350 s) by target | only after C1 + C2 | |

Fixed times that cannot shrink: the 60 s fuzz windows in Go and Swift (set by the suites), Maven Central's own publishing delay (about 20 minutes today).

## 6. Loop 30 (AZ-2600): C1 + C2 and T3 done, T1 unproven, T2 decided

### test.yml after C1 + C2 (run 38921222391, commit 4281aa9, `dev` push, 15 jobs)

| Job | Seconds | | Job | Seconds |
|-----|--------:|-|-----|--------:|
| `publish-gate-readonly` | 415 | | `suites (swift, tests)` | 284 |
| `suites (swift, gates)` | 379 | | `publish-gate-rest` | 259 |
| `publish-gate-phases` | 324 | | `ring` | 245 |
| `embedded` | 317 | | `suites (go)` | 161 |

The other jobs: `suites` python 111, csharp 79, cpp 61, rust 57, typescript 39, java 30; `scaffold` 71. Wall time 418 s (run created 15:06:29, last job done 15:13:26), against 980 to 1 095 s before (`suites` 896 to 1 026 s, `publish-gate` 977 to 1 091 s): about 9 to 11 minutes saved on every push. The new long poles are `publish-gate-readonly` (350 s group + image pull) and `suites (swift, gates)`. Per-group seconds of the gate: readonly 350; gate 68, pins 17, phases 152; swift 181, workflow 34, vcpkg 21, go 10, npm 6, registry 1, the rest 0. One run proves one point (the same code varies by about 1.5x): the close push of this loop (run 38997835591, `5790486`, same job layout, only docs and a test change after `4281aa9`) took 382 s: `publish-gate-phases` 379, `suites (swift, tests)` 342, `embedded` 337, `publish-gate-readonly` 333, `ring` 304, `suites (swift, gates)` 284, `publish-gate-rest` 273, go 158, python 111, csharp 88, rust 60, `scaffold` 59, cpp 55, typescript 43, java 25 s. Two runs: 418 and 382 s (median 400 s), against 892 to 1 396 s before.

No check was removed: 14 gate groups before and after (each runs in exactly one of the three jobs, enforced by `publish-jobs.test.sh`); 8 languages before and after (9 matrix entries, Swift as two parts that run exactly the steps of the single run, enforced by `run-suite-swift.test.sh`); `run:` steps in `test.yml` 19 to 24 (7 jobs, was 5); mutants of the layout guard 14 to 45.

### T3: why the Go proxy needed 19 minutes

The log of the v0.3.0 publish job: the tag was pushed at 12:06:00.75; the first proxy request at 12:06:01.94 answered `404 ... invalid version: unknown revision go/v0.3.0`; tries 2 to 38 (every 30 s) got the same answer; try 39 at 12:25:20 answered. The proxy had asked GitHub for the tag 1.2 s after the push and found nothing, and it caches such a miss (golang/go#40170: the cache can last about 30 minutes, nothing flushes it; advice: do not request a version before it is tagged, or wait). Our own first request was the poisoning request. Fix (`publish-go.sh`): after pushing, wait until the tag shows on an anonymous `git ls-remote` (up to 120 s), then 30 s more, then ask the proxy; the check is unchanged and a tag that was already there is not waited for. Expected: a Go wait of about 1 minute instead of 19. Unproven until the next tag (a Go tag is permanent, so no test tag was pushed); if the proxy still caches a miss the wait is as before.

### T2 decision (owner, 2026-10-16: option B, "T3 plus Swift check early")

With T3 the Go wait is no longer the long one, so T2 would save about 2 to 3 minutes of a 25 minute publish job, not 20. Option B's Swift part (start the Swift consumer check while Maven Central still publishes) was not built: ADR-005 says the check "runs after every registry upload and after the Go tag" and `publish-swift-gate.test.sh` asserts that the Go tag is there when Swift resolves; the gain is about 70 s. It needs an ADR amendment first. Left open for the owner (see the loop 30 record).

### Result table

| Item | Before | After | Status |
|------|-------:|------:|--------|
| test.yml wall | 980 to 1 095 s | 418 and 382 s | measured (2 runs) |
| `suites` | 896 to 1 026 s (one job) | longest job 379 s | measured |
| `publish-gate` | 977 to 1 091 s (one job) | longest job 415 s | measured |
| Go proxy wait on a tag | 1 158 s | about 60 s expected | unproven until the next tag |
| tag run repeated tests (T1) | 13 min | 0 expected | unproven until the next tag |
| Maven wait | 1 187 s | unchanged | Maven's own delay |

## 7. Loop 31 (AZ-2607): read-only split, Swift in three parts, embedded in three jobs, Mac gate in parallel

Per-job seconds of every group, step and embedded target now come from one "timing" notice annotation per job (readable without a token: `curl -s "https://api.github.com/repos/zxsanny/packbin/check-runs/<job id>/annotations?per_page=100"`); the job ids are in `.../actions/runs/<run id>/jobs`. Full job tables of both runs: `_docs/loops/loop31/notes31.md`.

| Run | Commit | Jobs | Wall | Longest jobs (s) |
|-----|--------|-----:|-----:|------------------|
| 38997835591 (loop 30 close) | `5790486` | 15 | 382 s | phases 379, swift tests 342, embedded 337, readonly 333 |
| 39012012655 (batch 1) | `29c0ab6` | 17 | 375 s | swift gates 371, embedded 360, publish-gate-rest 306, phases 278 |
| 39014663944 (batch 2 + C4) | `0fc35f8` | 20 | 344 s | readonly-gate 341, phases 285, swift gates 282, ring 265, swift tests 249 |
| 39018150736 (second run of the final code, AC-1) | `fbce19f` (close push, docs only) | 20 | 369 s | readonly-gate 365, phases 286, swift gates 282, ring 257, swift tests 248 |

AC-1: the median of the two runs of the final layout is 356.5 s (344 and 369 s), at most 360 s: met by 3.5 s; the second run alone is above the target. The `readonly-gate` group was 139, 200 and 278 s on the three runs: it defines the wall and is the next cut.

| Item | Before | After | Status |
|------|-------:|------:|--------|
| `test.yml` wall | 418 and 382 s (median 400 s) | 375 s (batch 1), then 344 s and 369 s (final layout, median 356.5 s) | AC-1 met on the median of two runs |
| `readonly` gate group | 247 to 350 s, one group | 18 s + 139 to 200 s + 32 s, three groups | measured; `readonly-gate` (three gate runs at once) varies 1.4x |
| `embedded` | one job, 317 to 360 s | `embedded-esp-core` 209, `embedded-esp-packages` 157, `embedded-arm` 52 s | measured |
| Swift | two parts, 284 to 342 s and 284 to 379 s | tests 249, gates 282, speed 227 s | measured; gates is the longest (two builds, 95 + 97 s) |
| `swift` gate group | 195 to 215 s inside `rest` | 153 to 157 s in its own job | measured |
| Mac `publish-gate` stage | 1 141 s (loop 30), 754 s (loop 29) | 613 s (5 shares at once; sum 1 901 s, ratio 0.32) | measured at step 11 (load 20 to 100) |
| Jobs per push | 15 | 20 (the free plan runs 20 at the same time; a `dev` + `main` push is 40) | counted; queueing on a double push not measured |
| Checks | 14 gate groups, 8 languages in 9 matrix entries, 45 layout mutants | 16 gate groups, 8 languages in 10 matrix entries, 66 layout mutant calls, 9 embedded targets in 3 parts | each in exactly one place, enforced |

Next long poles, in order: `publish-gate-readonly-gate` (341 s: three gate runs at once on the runner, plus about 85 s of image pull, plus `pins` 26 s), `publish-gate-phases` (285 s: 222 s of scenarios plus the pull), the Swift `gates` part (282 s), `ring` (265 s, unchanged). Not done: caches (C3), the PlatformIO install in the Arduino-ESP32 target, one pull for several gate jobs.

## 8. Loop 32 (AZ-2625): read-only gate in three jobs, phases in two, pins moved, Swift strict build merged

Read as in section 7 (one jobs call and one annotations call per job, no token). Jobs: 23 per push (20 before): `publish-gate-readonly-gate` became three jobs, `publish-gate-phases` two; the free plan runs 20 jobs at the same time, so up to three jobs wait for a slot.

| Run | Commit | Jobs | Wall | Longest jobs (s, duration; wait for a slot in brackets) |
|-----|--------|-----:|-----:|----------------------------------------------------------|
| 39018150736 (loop 31 close) | `fbce19f` | 20 | 369 s | readonly-gate 365, phases 286, swift gates 282, ring 257, swift tests 248 |
| 39024316436 (loop 32, batch 1) | `c0e8019` | 23 | **275 s** | ring 273, swift tests 246, readonly-gate-good 184 (63) = 247, swift speed 224, embedded-esp-core 213, readonly 205, rest 205, phases 196, swift gates 191 |

Group and step seconds of run 39024316436, against the loop 31 runs:

| Item | Loop 31 | Loop 32 |
|------|--------:|--------:|
| `readonly-gate` (three gate runs at once) | 139, 200, 278 | `-good` 121, `-bad` 88, `-nojava` 94 (one job each) |
| `phases` | 221 | `phases` 105 + `phases-rerun` 108 (Mac profile: 143 s against 143 s) |
| `pins` (in the `readonly-gate` job) | 26 | 26 (in `publish-gate-rest`, total 138) |
| Swift `gates` part | 246 (strict release build about 95) | 157 (resolve 5, tsan build 100, list 3, sanitized run 48, deps 1) |
| Swift `speed` part | 112 to 191 | 192 (resolve 4, `swift_speed` 188: the release build now carries the strict flags) |
| Swift `tests` part | 212 | 213 |
| job durations | readonly-gate 341 to 365, phases 285, swift gates 282 | readonly-gate-good 184, phases 196, swift gates 191 |
| waits for a slot | none | `readonly-gate-good` 63 s, `suites (rust)` 35 s, `readonly-gate-nojava` 30 s (the jobs that start late are not the last in the file) |

The wall is `ring` (273 s, unchanged since loop 28) with `suites (swift, tests)` (246 s) second; nothing the loop cut is on the critical path any more. Mac profile of the loop 31 `phase_checks` (one run, seconds): static 1, setup 15, fabricated 1, empty plan 0, build-only 30, full publish 27, failure injection 48, pipeline violations 21, re-run checks 128 (total 272); the cut is by these seconds.

| Item | Before (loop 31) | After (loop 32) | Status |
|------|-----------------:|----------------:|--------|
| `test.yml` wall | 375 s, then 344 s and 369 s (final layout, median 356.5 s) | 275 s (run 1); run 2 is the close push, in `_docs/loops/loop32/notes32.md` | AC-1 (median of two at most 330 s) met on run 1 alone by 55 s |
| Jobs per push | 20 | 23 (three waited 30 to 63 s for a slot, none set the wall) | counted and measured |
| Mac `publish-gate` stage | 613 s (5 shares, sum 1 901 s, ratio 0.32) | 391 s (8 shares, sum 2 395 s, ratio 0.16) | measured at step 11 (load 20 to 69) |
| Step 11 | 1 341 s, 3 suites on the serial retry | 902 s, no retry | measured |
| Checks | 16 gate groups, 66 layout mutant calls | 19 gate groups, 77 layout mutant calls, `ph_split` and `ro_split` mutants, 19 Swift mutants | each in exactly one place, enforced |

Next long poles, in order: `ring` (273 s), `suites (swift, tests)` (246 s), `readonly-gate-good` (247 s including 63 s of waiting), `suites (swift, speed)` (224 s), `embedded-esp-core` (213 s). Not done: caches (C3), per-job pull lists (swift is 4 GB and seven gate jobs pull it), the PlatformIO install in the Arduino-ESP32 target, splitting `ring`.
