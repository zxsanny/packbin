# Loop 30 notes — CI speed (AZ-2600)

## Design as built

- `run-suite.sh swift`: `PACKBIN_SWIFT_PART` unset or `all` = every step (the Mac), `tests` = resolve, strict release build, debug build, tests, list, fuzz; `gates` = resolve, sanitizer build, list (of the sanitizer build), sanitizer run, release speed run, dependency check. Unknown part: FAIL row, no step. Mac Docker (swift:6.3.3, load 5): tests part 197 s, gates part about 200 s (28 + 77 + 93); CI: 284 and 379 s.
- `publish-gate.test.sh --groups a,b`: `gate_groups` is the one list of the 14 groups; `group <name> <fn>` runs a group through `timed` when selected; unknown or empty list exits 2; no argument runs all 14.
- `test.yml`: `suites` matrix (`include`, `fail-fast: false`, 9 entries), `publish-gate-readonly` (readonly), `publish-gate-phases` (gate, pins, phases; images pulled), `publish-gate-rest` (the other ten groups; no pull).
- `publish-go.sh` (T3): after a push, wait for the tag on an anonymous ls-remote (120 s) and 30 s more before the first proxy request.

## Mutation proofs (all rejected)

| Guard | Mutants | Result |
|-------|--------:|--------|
| `publish-jobs.test.sh` (layout: matrix entries, fail-fast, env, gate groups, pulls, needs/if/continue-on-error/timeout, a leftover `publish-gate` job, a new unrun group, a renamed group) | 45 | 45 rejected |
| `run-suite-swift.test.sh` (parts) against `run-suite.sh` | 8 | 8 KILLED (tests part runs gates, gates part runs tests, gates part without list / deps / speed, tests part without fuzz / strict build, unknown part accepted) |
| `publish-timing.selftest.sh` (groups) against `publish-gate.test.sh` | 9 | 9 KILLED (selection ignored, unknown group accepted, empty list accepted, default selection, missing group call, group wired to another function, group outside `group`, list loses a name, comma not split) |
| `publish-go.test.sh` (T3) against `publish-go.sh` | 6 | 6 KILLED (no settle pause, no visibility wait, failed wait does not fail, wait for a tag already there, proxy asked after a failed wait, ls-remote failure read as not visible) |

One mutant survived first (no settle pause: the test checked the printed line, not the time); the test now measures the run time (settle 6 s) and the mutant is killed.

## Counts before and after

`test.yml`: 5 jobs and 19 `run:` steps to 7 jobs and 24; gate groups 14 to 14 (each in exactly one job); languages 8 to 8 (9 matrix entries); `publish-jobs.test.sh` mutants 14 to 45; Swift steps 12 in one run, 14 in the two parts (resolve and list run twice, nothing else does).

## T3 evidence

See `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 6 (log of publish run 38894017715, golang/go#40170).

## Findings of the total review (7, code-review high)

Fixed: ls-remote failure read as "tag not visible" (now a named query failure, with a test and a mutant); CI document updated. Skipped with reason: settle default unproven (cannot be tested without a permanent Go tag); 30 concurrent jobs on a dev + main push (free-plan queueing, no wrong result); pull line copied in two jobs (GitHub Actions has no anchors across steps); guard's fixed container-group list; gates part lists tests of the sanitizer build (verified in the real image, 3 s).
