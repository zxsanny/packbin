---
loop: 31
branch: dev
---

# Loop 31 — CI speed 2 and the Mac gate (AZ-2607, epic AZ-2223)

Owner (2026-10-17): accepted all six recommendations of `_docs/loops/loop30/handoff31.md` in one batch.

## What

- **CI wall (`test.yml`) 382 to 418 s → at most 360 s.** The long poles after loop 30 are `publish-gate-readonly` (415 / 333 s; the `readonly` group is 350 s of it), `publish-gate-phases` (324 / 379 s), the two Swift parts (284 / 379 and 342 / 284 s) and `embedded` (317 / 337 s, not split this loop). Split the `readonly` group into finer groups (`readonly`, `readonly-gate`, `readonly-full`) and spread the gate groups over the gate jobs by measured seconds; balance the two Swift parts by per-step seconds.
- **Timing readable without a token.** The gate already writes one notice per job with its group seconds; the Swift parts (and every suite) write one notice with their step seconds, so the rebalance is decided from the check-run annotations, not guessed.
- **Mac gate in parallel.** The `publish-gate` stage of `scripts/loop-tests.sh` (1 141 s at load 10 to 21 in loop 30, 754 s in loop 29) runs the same shares as the CI gate jobs at the same time, read from `test.yml` (one list).
- **`publish-phases.test.sh`** (501 lines) under the 500-line cap, split by responsibility.
- **review28 #4:** audit `scripts/` and `.github/workflows/` for a host delete of a path right before a container binds it (the loop 28 cpp race); fix or prove harmless each site.

Closed by the owner's batch: T2 option B (no ADR-005 amendment). Not in scope: C3 (caches), C4 (embedded split), AZ-2068, any tag or registry upload, F44, the `main` push.

## Code sections / UI locations for this loop

Named in the handoff the owner accepted (backend only, no UI):

- `.github/workflows/test.yml` (gate jobs, `suites` env), `.github/workflows/publish-gate.test.sh` (`gate_groups`, `group` calls), `.github/workflows/publish-readonly.test.sh` (`readonly_checks`), `.github/workflows/publish-timing.test.sh`
- `.github/workflows/run-suite.sh` (Swift parts, step timing), `docker-compose.test.yml` (env forwarded to the suite)
- Guards: `publish-jobs.test.sh`, `run-suite-swift.test.sh`, `publish-timing.selftest.sh`, `run-suite.test.sh`
- `scripts/loop-tests.sh` and `scripts/loop-tests.test.sh` (the `publish-gate` stage)
- `.github/workflows/publish-phases.test.sh`
- Audit: `scripts/*.sh`, `.github/workflows/*.sh`, `cpp/embedded/*.sh`

## Expected results

| Input | Expected |
|-------|----------|
| `test.yml` run of the final code on a `dev` push, twice | wall time median ≤ 360 s; every job green |
| check-run annotations of each gate job and each suite job | one notice per job with the seconds of every group / step |
| `publish-gate.test.sh --groups <x>` with a group not in `gate_groups` | exit 2, names the group |
| `publish-jobs.test.sh` on a `test.yml` that drops, repeats or invents a group | fails, names the group |
| `scripts/loop-tests.sh --all` on the Mac | `publish-gate` stage wall ≤ 0.7 × the sum of its shares' own seconds; a failing share fails the stage and is named |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The gate shares were never run at the same time in one tree (CI gives each job its own checkout); one share writing into the tree breaks another's tree hash | prove with a tree manifest before and after the parallel stage; a share that writes the tree is fixed or runs after the others, with the reason in the notes | open | High |
| A regrouping that drops a gate check or a Swift step passes silently | guards count the check functions per group and the steps per part; one mutant per rule | open | High |
| AC-1 needs two CI runs; pushes of `dev` are asked each time | owner go per push | open | Medium |
| The same code varies about 1.5x between CI runs | median of 2 runs, never one run as proof | open | Medium |
| 16 jobs per push; a `dev` + `main` push is 32 against 20 concurrent | report; `main` is not pushed this loop | open | Low |
