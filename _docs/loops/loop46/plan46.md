# Autodev Loop Plan — Loop 46

loop: 46
kind: product
confirmed: true
branch: dev
ship: false

Intake: hopper hit. The loop 45 record and `handoff46.md` hold the work the owner decided on 2026-10-20 ("accept all six", "small items now, tests next loop"): concurrency tests, the random and hostile counts, the repeated-text speed test, the protected session ring row, three documentation leftovers. No interview. Epic AZ-2645. The retrospective is due (5 loops since loop 41).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at intake: `feature-description.md`, scenarios flipped, five specs |
| decompose-feature | 9.5 | Decompose Feature | yes | done at intake: AZ-2735, AZ-2736, AZ-2737, AZ-2739, AZ-2740 (15 points) |
| implement | 10 | Implement | yes | one batch; package workers in two waves of four, the parent does the documents |
| feature-assess | 10.5 | Feature Assessment | no | loop 45 assessed these exact rows; this loop only adds the tests the report named (owner-run if wanted) |
| run-tests | 11 | Run Tests | yes | one run at HEAD; stages with unchanged inputs are skipped |
| test-spec-sync | 12 | Test-Spec Sync | yes | CS-5 and CS-10 change; the new tests need matrix rows (matrix stays ≤ 500 lines) |
| update-docs | 13 | Update Docs | no | no contract change |
| security | 14 | Security Audit | no | report dated 2026-10-19; only tests are added |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 5 loops since `retro_2026-10-19_loop41.md` |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke46.md` |

## Implementation

### Files that change
- AZ-2735: new test files in `csharp/tests`, `java/src/test`, `rust/src` (plus the `mod` line), `go/`, `swift/Tests`.
- AZ-2736: new test files in `python/tests`, `csharp/tests`, `swift/Tests`; `go/` payload count; `_docs/02_task_plans/compact-strings/acceptance_criteria.md` (parent).
- AZ-2737: new test files in `java/src/test`, `csharp/tests`, `rust/src`, `cpp/tests`; a walker only if a test fails.
- AZ-2739: `.github/workflows/language-pair.sh`, `ring-wiring.test.sh`, the eight drivers under `.github/workflows/drivers/`.
- AZ-2740 (parent): `_docs/02_document/tests/`, `scripts/text/size_report.py`, `size_report.md`.

### Order of work
Tracker In Progress; wave 1 = C#, Swift, Go, CI (AZ-2739); wave 2 = Java, Rust, C++, Python. Each worker does every task of its package and runs only that package's focused tests. The parent does AZ-2740 and the criteria edit meanwhile. Then one total review, test-spec sync, one step 11 run, retro, smoke, close, push `dev` and `main`.

### Proof
Each package's focused suite green; the ring prints "language pairs passed"; the size script twice gives one file; step 11 once at HEAD.

### Risks
A new test finds a real defect (CS-D7 walker, a hostile payload, a ring mismatch): stop and report, never weaken the test. The Mac load (other sessions) makes timings and the ring slow: load-aware helpers, status line every 30 s on long runs.

## Assessment rounds

None.
