---
loop: 32
branch: dev
---

# Loop 32 — CI speed 3 (AZ-2625, epic AZ-2223)

Owner (2026-10-17): scope and order set in the loop 32 start message, from `_docs/loops/loop31/handoff32.md`. The batched question (D1 to D6) was answered "accept all, target 330 s": D1 median at most 330 s; D2 23 jobs, long jobs first in `test.yml`, queue wait read from the first run; D3 strict release build merged into the speed part's release build (fallback: a fourth part); D4 groups `readonly-gate-good|bad|nojava`, `phases` + `phases-failures`, `pins` into `publish-gate-rest`; D5 one more code push allowed if the first run misses; D6 ring and C3 out.

## What

`test.yml` wall was 344 s and 369 s on the two runs of the loop 31 code (runs 39014663944 and 39018150736, median 356.5 s; 375 s on the batch 1 run). `publish-gate-readonly-gate` set the wall on all three runs: its `readonly-gate` group ran 139, 200 and 278 s because `ro_gate_checks` runs three real gate scenarios (good, bad, nojava) at the same time on one 4-core runner. In the owner's order:

1. **`readonly-gate` → three groups and three jobs**, one scenario each (`good`, `bad`, `nojava`); each about 70 to 125 s of gate plus the 60 to 90 s image pull.
2. **`pins` (26 s) out of that job** into a gate job that already pulls the images.
3. **`phases` (221 to 222 s of scenarios) → two groups**: the success scenarios and the failure scenarios, each paying `ph_setup`.
4. **Swift `gates` part (282 s: strict release build 95, thread-sanitizer build 97, sanitized run 49)** cut by moving the strict release build.

Goal: `test.yml` wall at about 5 minutes. No check removed; every group, Swift step and embedded target in exactly one job.

Not in scope: C3 (caches, one pull for several gate jobs), `ring` (257 to 271 s, unchanged), the PlatformIO install in the Arduino-ESP32 target, AZ-2068, any tag or registry upload, F44, the `main` push.

## Code sections / UI locations for this loop

Backend only (CI and test scripts), named in the owner's start message and the loop 31 notes:

- `.github/workflows/test.yml` (gate jobs, suites matrix, job order)
- `.github/workflows/publish-gate.test.sh` (`gate_groups`, the `group` lines), `publish-readonly.test.sh` (`ro_gate_checks`), `publish-phases.test.sh` and `publish-phases-failures.test.sh` (`phase_checks`), `publish-pins.test.sh`
- `.github/workflows/run-suite.sh` (Swift parts and steps), `docker-compose.test.yml` if a part name changes
- Guards: `publish-jobs.test.sh`, `run-suite-swift.test.sh`, `publish-timing.selftest.sh`, `cpp/embedded/run-parts.test.sh` (only if embedded changes), `scripts/loop-tests.sh` + test (reads the shares from `test.yml`; no list to edit)
- Docs: `_docs/04_deploy/ci_cd_pipeline.md`, `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` (section 8), `_docs/02_document/module-layout.md`

## Acceptance criteria

(Target set by the owner's batch answer, 2026-10-17: median at most 330 s, all other recommendations accepted.)

**AC-1: CI wall.** Given the final code, when `test.yml` runs on two `dev` pushes, the median wall time (run created to last job done) is at most 330 s (loop 31: 344 and 369 s, median 356.5 s; the goal behind it is about 5 minutes) and every job is green.

**AC-2: readonly-gate in three jobs.** Given `publish-gate.test.sh`, the three gate scenarios `good`, `bad`, `nojava` are three groups (`readonly-gate-good`, `-bad`, `-nojava`), each calls a function that runs exactly one scenario and applies exactly the assertions that scenario had (the shared parts of `ro_gate_checks` become one helper); each group runs in its own job; on CI each of the three jobs is at most 220 s.

**AC-3: pins moved.** `pins` runs in `publish-gate-rest` (which pulls the images); no readonly-gate job runs it.

**AC-4: phases in two groups.** `phase_checks` becomes two groups, success scenarios (`phases`) and failure scenarios (`phases-failures`), in two jobs; each of the 8 phase check functions (`ph_static_checks`, `ph_fabricated_checks`, `ph_empty_plan`, `ph_build_only`, `ph_full_publish`, `ph_failure_injection`, `ph_pipeline_violations`, `ph_rerun_checks`) runs in exactly one group; both jobs are at most 220 s on CI.

**AC-5: Swift gates part.** The strict release build (`-warnings-as-errors`, `-strict-concurrency=complete`, SW-9) still runs on every `all` and CI run, in exactly one part; the `gates` part is at most 200 s on CI and no Swift part is above 250 s; every Swift step runs in exactly one part (`run-suite-swift.test.sh`).

**AC-6: no check lost.** `publish-jobs.test.sh` holds every gate group (19: the 16 of loop 31, minus `readonly-gate`, plus three scenario groups and `phases-failures`) in exactly one job and every container group after the image pull; `publish-timing.selftest.sh` holds the three scenario functions and the 8 phase check functions to exactly one group each; one mutant per changed rule is rejected, and the five guards named in the start message pass.

**AC-7: queue and job count.** The layout has 23 jobs per push (20 today) against the free plan's 20 concurrent jobs. The first CI run's jobs API data (`created_at`, `started_at`, `completed_at`) is read and the queue wait of every job is written to the notes; a job that waits more than 30 s and sets the wall is fixed in a second batch.

**AC-8: Mac gate.** `scripts/loop-tests.sh` runs the new shares read from `test.yml` (no second list), the tree manifest is the same before and after the stage, a failing share fails the stage and is named; the stage wall ratio to the sum of shares is read and reported (loop 31: 0.32).

**AC-9: file length.** Every changed source file is at most 500 lines.

## Expected results

| Input | Expected |
|-------|----------|
| `test.yml` run of the final code on a `dev` push, twice | wall median at most 330 s; all jobs green |
| `publish-gate.test.sh --groups readonly-gate-bad` | only the bad-fixture gate scenario runs, with its three assertions (exit non-zero, no plan, unchanged tree) |
| `publish-gate.test.sh --groups phases` / `--groups phases-failures` | the success / the failure scenarios; each alone passes on a clean tree |
| `publish-jobs.test.sh` on a `test.yml` that drops, repeats or invents a group | fails, names the group |
| `run-suite-swift.test.sh` on a plan that drops, repeats or invents a step | fails, names the step |
| `scripts/loop-tests.sh` on the Mac | the new shares run at the same time, tree unchanged |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| 23 jobs against the free plan's 20 concurrent: the last jobs wait for a slot, and `ring` (257 to 271 s, last in the file today) is the job most hurt by waiting | order the long jobs first in `test.yml`; read the jobs API times on the first run; second batch if a long job waits | open | High |
| `ring` (257 to 271 s, 245 to 304 s over earlier runs) and `suites (swift, tests)` (248 s) are untouched floors: a wall of 330 s leaves them 55 to 85 s of slack | report honestly if the target is missed; ring is the next candidate | open | Medium |
| Merging the strict release build into the speed part's release build changes what the speed build compiles (test targets also under `-warnings-as-errors`) | one real container run of the exact command before the push; fall back to a fourth part if the tests are not warning-free | open | Medium |
| Splitting `phases` and `readonly-gate` by structure, not by measured seconds (no per-function timing exists) | profile the phase functions once on the Mac; the first CI run's group notices decide a second batch | open | Medium |
| The same code varies about 1.4x between CI runs | median of two runs; never one run as proof | open | Medium |
| Mac under another project's load: timing-bound tests miss in the parallel pool | read both logs (pool and serial retry) | open | Low |
