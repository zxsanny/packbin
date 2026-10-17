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
