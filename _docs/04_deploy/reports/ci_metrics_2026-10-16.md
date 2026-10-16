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
