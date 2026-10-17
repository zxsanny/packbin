---
loop: 34
branch: dev
---

# CI speed 5: SwiftPM dependency caches with ccache, at most 20 jobs

**Task**: AZ-2627_ci_speed_5
**Name**: CI speed 5
**Description**: `test.yml` wall time falls to a median of at most 225 s (loop 33 code: 251, 225, 273 s) by caching the four Swift builds' output with their C compiles through ccache, and by merging short suite jobs so the workflow has at most 20 jobs and no job waits for a runner slot; no check is removed.
**Complexity**: 5 points
**Dependencies**: AZ-2626
**Component**: ci
**Tracker**: AZ-2627
**Epic**: AZ-2223

## Problem

The longest jobs are the Swift ones, and every Swift build starts from nothing on every push: `suites (swift, tests)` 188 to 248 s (debug build 48 to 99 s), `suites (swift, speed)` 177 to 221 s (release build and speed tests 131 to 185 s), `suites (swift, gates)` 154 to 194 s (thread-sanitizer build 85 to 101 s), and `ring`, whose critical path is the swift pull plus the Swift driver build (84 to 120 s). The intake spike showed that a restored build directory reuses only swift-crypto's Swift modules: SwiftPM compiles BoringSSL's 372 C files again after any restore. With 23 jobs and 20 runner slots, three jobs start late in every run; in run 39032007165 that was `ring` (+60 s), wall 273 s.

## Outcome

- The four Swift builds restore their output from a cache keyed on the build, the Swift image tag and the dependency manifests; their C compiles go through ccache, whose directory is in the same cache; a cache miss builds as today and saves the cache.
- Short suite jobs share a job: at most 20 jobs, none waiting for a slot.
- Each Swift job's timing notice gives the cache state and the ccache hits and misses.
- The owner's Mac runs (`scripts/loop-tests.sh`) stay as today.

## Scope

### Included
- `test.yml` (`suites` matrix and step, cache steps of the three Swift parts and `ring`, comments); `docker-compose.test.yml` `swift` service; the Swift steps and timing notice of `run-suite.sh`; `ring-swift.sh` (ccache in its container, installed as root, build as the caller); `ring-prepare.sh` if the timing notice changes there; guards and mutants: `publish-jobs.test.sh` (matrix rule), `run-suite-swift.test.sh` (ccache best-effort with a stand-in installer, the CI-only switch), `ring-wiring-swift.test.sh` (cache and build lines), `ring-prepare.test.sh` if touched; docs (`ci_cd_pipeline.md`, `ci_metrics_2026-10-16.md` section 10, `module-layout.md`).
- D4: the gcc pull after the swift pull in `ring`, only if the first measured run shows `ring` above the slowest non-Swift job.

### Excluded
- `publish-gate-swift` (its real consumer build from a bare repository stays from nothing), `publish.yml` (release builds stay from nothing), the PlatformIO install, a runner image pin, AZ-2068, tags, F44, the `main` push.
- Ccache or kept build output on the Mac (card 3).

## Acceptance Criteria

AC-1 to AC-11 are in `_docs/02_task_plans/ci-speed-5/problem.md` (owner answers 2026-10-17). In short:

**AC-1: CI wall.** Two `dev` pushes with primed caches: median wall at most 225 s, all jobs green.
**AC-2: no slot wait.** At most 20 jobs; every job starts within 15 s of the first.
**AC-3: cache hits.** All four Swift builds restore by exact key; the notice gives the state. (ccache clause withdrawn.)
**AC-4: build seconds.** `tests` debug build under 48 s, `gates` sanitizer build under 85 s, `speed` step under 131 s, ring `swift-drivers` under 84 s.
**AC-5: a miss is today.** No entry or a failing cache service: builds from nothing, tests pass, cache saved.
**AC-6: withdrawn** (ccache removed in batch 2, 2026-10-17: the restore keeps nanosecond times, so CI recompiles no C file).
**AC-7: cache keys.** Build, image tag, hash of `Package.swift` and `Package.resolved`; no save on an exact hit; at most 3 GB per dependency set.
**AC-8: merged suites.** Each language in exactly one job; a failing suite fails the job by name, the others still run; guard and mutants.
**AC-9: Mac unchanged.** `scripts/loop-tests.sh` passes; no ccache, no kept build output.
**AC-10: no check lost.** Every Swift step, group and embedded target in one job; named guards pass; a mutant per changed rule.
**AC-11: file length.** Changed files at most 500 lines.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-6, AC-9 | `run-suite-swift.test.sh` with a stand-in `swift` and a stand-in ccache installer that fails; the same with the CI switch off | the suite passes without ccache and the notice says "ccache unavailable" with the reason; with the switch off no install is tried |
| AC-3 | the same test with a stand-in installer that succeeds and a stand-in `ccache` printing hits and misses | the notice gives the cache state and the hits and misses |
| AC-8, AC-10 | `publish-jobs.test.sh` mutants: cpp in two entries, java dropped, a merged step that stops at its first failure, a merged step that does not name the failed language | each rejected, named |
| AC-7, AC-10 | `ring-wiring-swift.test.sh` / the guard that reads the cache steps: a key without the image tag, a key without `Package.resolved`, a Swift job without its cache step | each rejected, named |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5, AC-7 | the final code, first push (no cache entries) | `test.yml` jobs and notices | all green; Swift caches miss and are saved; cache sizes from the cache list | — |
| AC-1 to AC-4 | two later `dev` pushes that change no dependency | jobs API, job pages, notices | wall median ≤ 225 s; ≤ 20 jobs, starts within 15 s; all four caches hit, ccache ≥ 95 %; builds under the AC-4 bounds | — |
| AC-9 | the final tree on the Mac | `scripts/loop-tests.sh` | all stages pass, tree unchanged by the gate stage | — |

## Constraints

- Owner decisions D1 to D4 and the C3 design pick (`problem.md`): `actions/cache` pinned by SHA; ccache from Ubuntu's apt in the container (approved download).
- No tag, no registry upload, no `main` push; each `dev` push is asked of the owner.
- One total review and one step 11 run; no per-batch review or test run.

## Flagged concerns

See `_docs/02_task_plans/ci-speed-5/problem.md` § Flagged concerns (no Critical; the release-build reuse, the ring's root install, the Ubuntu 26 move and CI variance open).
