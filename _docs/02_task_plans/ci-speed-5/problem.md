---
loop: 34
branch: dev
---

# Loop 34 — CI speed 5 (AZ-2627, epic AZ-2223)

Owner (2026-10-17): answered the loop 34 batch (D1 to D4, built from `_docs/loops/loop33/handoff34.md`) with "accept all recommended": D1 C3, cache the SwiftPM dependency build (swift-crypto) for the three Swift suite jobs and the ring's driver build, and merge short suite jobs so the workflow has at most 20 jobs; D2 median of two runs at most 225 s, no job waiting for a slot; D3 `actions/cache` pinned by SHA (new to the repository); D4 pull gcc after swift in `ring` only if the first measured run shows `ring` above the floor, no separate ask. AZ-2068 stays in `todo/`.

## What

`test.yml` on the loop 33 code took 251, 225 and 273 s (runs 39031026351 `19f4c33`, 39031606844 `2da10a6`, 39032007165 `dadd32b`; 23 jobs, all green). Job seconds (run 1 / 2 / 3; `+n` is the start delay):

| Job | Run 1 | Run 2 | Run 3 |
|-----|------:|------:|------:|
| `suites (swift, tests)` | 248 | 188 | 246 |
| `publish-gate-readonly` | 211 | 222 | 198 |
| `suites (swift, speed)` | 221 | 177 | 219 |
| `ring` | 209 | 202 | 213 (+60) |
| `publish-gate-swift` | 207 | 183 | 189 |
| `embedded-esp-core` | 202 | 206 | 197 |
| `publish-gate-rest` | 160 | 202 | 185 |
| `suites (swift, gates)` | 187 | 154 | 194 |
| `suites (csharp)` | 87 | 83 | 82 (+41) |
| `suites (rust)` | 73 | 71 (+71) | 59 |
| `embedded-arm` | 59 | 70 | 58 |
| `suites (cpp)` | 44 (+61) | 56 (+66) | 43 |
| `suites (typescript)` | 37 (+88) | 39 (+26) | 38 |
| `suites (java)` | 23 (+74) | 25 | 26 (+44) |

Swift steps from the `swift (...) suite timing` and `ring preparation timing` notices:

| Step | Run 1 | Run 2 | Run 3 |
|------|------:|------:|------:|
| tests: `swift build --build-tests` (debug) | 99 | 48 | 97 |
| tests: `swift test --skip-build` | 37 | 21 | 37 |
| tests: `swift_fuzz` (60 s by design) | 72 | 66 | 71 |
| speed: `swift_speed` (release build with tests, strict flags, then the speed tests) | 185 | 131 | 181 |
| gates: `swift build --build-tests --sanitize=thread` | 101 | 85 | n/r |
| ring: `swift-drivers` (release, `--static-swift-stdlib`) | 84 | 89 | 120 |
| ring: `pull-swift` / `pull-gcc` (in parallel) | 68 / 73 | 62 / 71 | 37 / 41 |

Every Swift build starts from nothing on every push: the suite containers keep their build output in `/tmp/packbin-swift-build` inside the container (`docker-compose.test.yml` `PACKBIN_SWIFT_SCRATCH`), the ring builds into `/tmp/packbin-ring-swift` on a fresh runner. In every run three jobs wait for a runner slot (23 jobs, 20 at a time on the free plan); which three is chance, and in run 3 it was `ring` (+60 s), which made the wall 273 s.

1. **C3, SwiftPM dependency caches**: the build output of the three Swift suite parts and of the ring's Swift driver build is restored from `actions/cache` before the build and saved only when the dependencies change.
2. **At most 20 jobs**: short suite jobs merge so no job waits for a slot.
3. **D4**: the gcc pull moves after the swift pull in `ring` only if the first measured run shows `ring` above the floor.

### Spike (2026-10-17, intake, `swift:6.3.3` on the Mac, `-j 4`)

A cold debug build with tests compiles 565 units: 372 BoringSSL C files (swift-crypto's `CCryptoBoringSSL`), 100 swift-crypto Swift units (`Crypto`, `CryptoBoringWrapper`) and 93 of the package's own (`Packbin`, `PackbinTests`). After the build directory went through a tar and back (new file identities, the old times kept) and the sources were touched (a fresh checkout), the rebuild compiled 465 units: the 100 swift-crypto Swift units were reused, all 372 C files were compiled again (SwiftPM tracks a C file by its identity, which no cache restore keeps). Mac times 40 s cold, 32 s after the restore (the Mac was loaded; only the unit counts carry over to CI).

The owner chose cache plus ccache (2026-10-17, after the spike): SwiftPM takes its C compiler from `CC`, and `CC=/usr/lib/ccache/clang` sends every C compile through ccache (the `--toolset` file's `cCompiler` is ignored for a host build). On a test package with a C target, a rebuild after the same restore ran the 3 C compiles again and ccache answered all 3 from its cache (3 of 3 hits, binary correct). ccache 4.9.1 comes from Ubuntu 24.04's apt in the container (new download per job, owner-approved).

**Correction (2026-10-17, after measured run A).** The spike's conclusion was an artifact of its method: GNU tar's default format keeps file times to the second, so the round trip changed every time's fraction and SwiftPM rebuilt the C files; with `tar --posix` (nanosecond times, as actions/cache keeps them) a test package rebuilt 0 of 3 C files. On CI the restored build compiled no C file at all (run 39040035812: ccache asked 0 times in all four builds). The owner removed ccache (batch 2, 2026-10-17); AC-6 and the ccache clause of AC-3 are withdrawn.

## Code sections / UI locations for this loop

Backend only (CI and test scripts), named in the owner's batch answer: "the three Swift suite jobs and the ring's driver build" and "merge short suite jobs so the workflow has at most 20 jobs".

- `.github/workflows/test.yml` (`suites` matrix and step, `ring` job, the cache steps)
- `docker-compose.test.yml` (`swift` service), `.github/workflows/run-suite.sh` (Swift steps, timing notice), `.github/workflows/ring-swift.sh`, `.github/workflows/ring-prepare.sh`
- Guards: `publish-jobs.test.sh` (suites matrix rule and mutants), `run-suite-swift.test.sh`, `ring-wiring-swift.test.sh`, `ring-prepare.test.sh`, `scripts/loop-tests.test.sh` if a step it reads changes
- Docs: `_docs/04_deploy/ci_cd_pipeline.md`, `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` (section 10), `_docs/02_document/module-layout.md`

## Acceptance criteria

(Targets from the owner's batch answer and the C3 design pick, 2026-10-17.)

**AC-1: CI wall.** Given the final code with its caches primed (the first push after a dependency change saves them and is not counted), when `test.yml` runs on two `dev` pushes, the median wall time (run created to last job done) is at most 225 s (loop 33 code: 251, 225, 273 s) and every job is green.

**AC-2: no slot wait.** `test.yml` has at most 20 jobs (today 23); on both AC-1 runs every job starts within 15 s of the run's first job (loop 33: three jobs started 26 to 88 s late in every run).

**AC-3: cache hits.** On both AC-1 runs, each of the four Swift builds (the `tests` debug build, the `gates` thread-sanitizer build, the `speed` release build, the ring's Swift driver build) restores its cache by exact key; the job's timing notice gives the cache state (hit or miss). (The ccache clause, "ccache answers at least 95 % of its C compiles", is withdrawn with ccache, 2026-10-17.)

**AC-4: build seconds.** On both AC-1 runs each of the four Swift builds is faster than the fastest loop 33 run of the same build: `tests` debug build under 48 s, `gates` thread-sanitizer build under 85 s, `speed` step under 131 s, ring `swift-drivers` under 84 s.

**AC-5: a miss is today.** On a cache miss (no entry for the key, or the cache service fails) every Swift build runs from nothing as today, all its tests run and pass, and the job saves the cache for the next run; proven by the first push of the final code.

**AC-6 (withdrawn 2026-10-17 with ccache): ccache is best-effort.** When the ccache install fails in the container, the build runs without ccache, the job's result comes from the tests alone, and the timing notice says ccache was unavailable with the reason; proven by a test with a stand-in failing installer.

**AC-7: cache keys.** The key of each cache names the Swift build, the Swift image tag and a hash of `Package.swift` and `Package.resolved`; a push that changes neither saves no cache (exact hit, no save step). The caches of one dependency set total at most 3 GB (the repository limit is 10 GB).

**AC-8: merged suites.** Every language's suite runs in exactly one job and Swift's three parts in one job each; in a job that runs several suites a failing suite fails the job, names the language, and the suites after it still run. `publish-jobs.test.sh` refuses a language run twice, a language missing, and a merged job that stops at its first failing suite, each by name, with a mutant each.

**AC-9: Mac unchanged.** On the Mac, `scripts/loop-tests.sh` passes (one total run); its Swift stage installs no ccache and keeps no build output between runs, as today; the tree is unchanged by the gate stage.

**AC-10: no check lost.** Every Swift step, gate group and embedded target still runs in exactly one job; the guards `publish-jobs.test.sh`, `run-suite-swift.test.sh`, `ring-wiring-swift.test.sh`, `ring-prepare.test.sh`, `publish-workflow.test.sh`, `scripts/loop-tests.test.sh` pass; one mutant per changed rule is rejected.

**AC-11: file length.** Every changed source file is at most 500 lines.

## Expected results

| Input | Expected |
|-------|----------|
| `test.yml` on the first push of the final code (no cache entries) | all jobs green; every Swift build a cache miss, timing as loop 33 plus the save; caches saved |
| `test.yml` on two later `dev` pushes that change no dependency | wall median at most 225 s; at most 20 jobs, each started within 15 s; every Swift cache a hit, ccache at least 95 % hits; each Swift build under its AC-4 bound |
| the Swift suite part with a stand-in ccache installer that exits 1 | the suite runs and passes without ccache; the notice says "ccache unavailable" with the reason |
| `publish-jobs.test.sh` on a `test.yml` that runs cpp in two jobs / drops java / lets a merged job stop at its first failure | fails, naming the language or the job |
| `scripts/loop-tests.sh` on the Mac | passes; no ccache installed, no Swift build output kept |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The spike was a debug build: whether the release builds (`speed`, ring drivers, whole-module optimization) reuse the restored swift-crypto Swift modules is unproven | the first two runs' notices show it; a release build that reuses nothing still gains the C part from ccache | open | Medium |
| A cache could give a wrong green (stale objects) | keys on the image tag, `Package.swift`, `Package.resolved` and the build; SwiftPM rebuilds the package's own targets after every checkout; ccache keys on preprocessed source and flags; `publish.yml` keeps building from nothing; a version number in the key to retire all caches at once | accepted-risk | Medium |
| ccache comes from Ubuntu's apt in every Swift job (an outside service, a few seconds) | best-effort: a failed install builds without it and says so (AC-6) | accepted-risk | Low |
| The ring's Swift container runs as the runner's user; the ccache install needs root | design in implement (install as root, build as the caller); the ring test covers it | open | Medium |
| `ubuntu-latest` moves to Ubuntu 26 from 2026-10-19, possibly under the measurement runs | the Swift builds run in `swift:6.3.3` (Ubuntu 24.04) whatever the runner; record the runner image of each run | open | Medium |
| 20 slots are per account: a run of another workflow at the same time still queues jobs | measure on runs with nothing else running | accepted-risk | Low |
| The same code varies about 1.4x between CI runs | median of two runs; never one run as proof | open | Medium |
