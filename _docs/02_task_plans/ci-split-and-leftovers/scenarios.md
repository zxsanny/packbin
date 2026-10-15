# Loop 28 scenarios

Status values: `confirmed` (proposed behavior accepted), `out-of-scope`. No `unknown` row.

## Fit (Part A)

| Component / flow | Today | After | Depends on today | Collision |
|------------------|-------|-------|------------------|-----------|
| `test.yml` job `scaffold` | one job: static checks, 8 suites, publish gate, in this order | three jobs (`scaffold` static checks, `suites`, `publish-gate`) beside `embedded` and `ring` | `publish.yml` (`uses: test.yml`, `needs: test`), 4 guards that read the job by name or step text | Card 1 |
| `publish-gate.test.sh` | 14 check groups run in one process, no timings | same groups, one timing line each | the gate's last line is grepped by the smoke scripts; mutant counts per group | none |
| `scripts/loop-tests.sh` stages `cpp` and `scaffold` | run in one pool, `cpp` first does `make -C cpp clean` | two pool stages never write the same path | `loop-tests.test.sh` (fake docker) | none (cause not yet pinned, concern) |
| README / ADR-005 Swift text | claims Swift 6.0+ and Xcode 16+ | adds the unproven limit; rewords Linux/CI claims to runs that happened | users reading the README; `publish-check.py` reads no README text | none |

### Card 1: how to split the scaffold job

**What breaks or changes for someone**
The owner waits 33 to 38 minutes for a CI answer because the 8 language suites and the publish gate run one after the other. Splitting makes them run side by side, so the wait falls to the longest part (the gate, about 18 to 21 minutes). The cost is that each job sets itself up and pulls its own container images.

**Why this happens**
Both parts sit in one job as consecutive steps, and the gate does not use anything the suites produce except container images that it can pull itself.

**Impact if we do nothing about it**
Slow feedback only; nothing is wrong. Every loop pays about 15 minutes of waiting per CI run.

**Ways to resolve**
- **Option A — three jobs, no matrix**: `scaffold` (static checks), `suites` (8 languages one after the other), `publish-gate`. Trade-off: the suites job stays about 15 minutes; the wall time is set by the gate.
- **Option B — one job per language plus the gate**: 10 jobs. Trade-off: the wall time falls further (the longest suite, about 5 minutes, then the gate), but 8 more runners each pull images and set up, and the report/guard wiring becomes a matrix.
- **Option C — leave it**: no change.

**Recommendation**: A — it meets the 25-minute bar with the smallest change; B can follow if the gate is cut.

Resolved: A (owner "accept all recommended", 2026-10-15). Constraint: the gate job must not rely on images the suites pulled (it pulls its own).

## Scenarios (Part B)

| ID | Axis | Actor and trigger | State | Behavior | Status | AC |
|----|------|-------------------|-------|----------|--------|----|
| S-1 | Existing-feature overlap | `publish.yml` runs `test.yml` on a version tag | new job layout | `needs: test` waits for all five jobs; a red `suites` or `publish-gate` blocks the publish | confirmed | SP-1 |
| S-2 | Invalid input | someone drops a suite or the gate step from `test.yml` | after the split | the guards refuse it and name the missing suite or step | confirmed | SP-4 |
| S-3 | Partial failure | `suites` fails while `publish-gate` passes | after the split | the workflow is red; `publish.yml` publishes nothing | confirmed | SP-1 |
| S-4 | First use | the gate job starts on a fresh runner with no pulled images | after the split | it pulls what it needs; no step assumes the suites ran first | confirmed | SP-2 |
| S-5 | Boundary values | gate takes 1 245 s on a slow runner | after the split | job `timeout-minutes` holds it; the `publish gate` step stays at most 1 500 s | confirmed | SP-2 |
| S-6 | Repeat | the gate test runs twice in a row on the Mac | timing lines added | same result; 14 timing lines each time | confirmed | SP-5 |
| S-7 | Partial failure | one gate check group fails | timing lines added | its timing line still prints, the failure count is unchanged, exit 1 | confirmed | SP-5 |
| S-8 | Concurrent | `cpp` and another pool stage run at once | after the cpp fix | each writes its own path; 0 serial retries in 3 runs | confirmed | CR-2 |
| S-9 | Existing data | a stale `cpp/build/` of the other OS (Mach-O vs ELF) is on disk | after the cpp fix | the `cpp` stage still builds (no manual `make clean` needed beyond what the stage does) | confirmed | CR-2 |
| S-10 | Boundary values | the Swift max-slots unpack at its default limits | peak memory measured | a figure in MB is recorded; above 1 000 MB opens a finding | confirmed | PM-1 |
| S-11 | Existing-feature overlap | a reader sees "Swift 6.0+" in the README | after the docs change | the same line carries the limit; no sentence claims an unrun toolchain | confirmed | DO-1, DO-2 |
| S-12 | Undo | the split makes CI worse | after the split | `git revert` of the one commit restores the single job (guards revert with it) | confirmed | SP-1 |
| S-13 | Existing-feature overlap | gate on the Mac in parallel | out of this loop | not done (owner did not choose it) | out-of-scope | — |
| S-14 | Existing-feature overlap | cutting the gate's unattributed ~750 s | out of this loop | next loop, from the timing lines | out-of-scope | — |
