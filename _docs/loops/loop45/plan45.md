# Autodev Loop Plan — Loop 45

loop: 45
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-19) took "Run /feature-assess" with scope "Both features": compact strings (epic AZ-2645, loops 35-37) and message ECC (epic AZ-2677, loops 38-40) plus the later fixes (AZ-2713, 2722, 2723, 2724, 2728). Hopper was empty. No code ships unless the verdict is EXTEND or CLARIFY, which re-enters through `protocols/feature-reentry.md` (max 2 rounds). F44 and the first v*/go/v* tags stay owner-run; the retrospective is due after this loop.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | no behavior is built; the grasped work is the assessment itself (like §Short loop on launcher); `new-task --extend/--clarify` runs only on a gap |
| decompose-feature | 9.5 | Decompose Feature | no | no feature description |
| implement | 10 | Implement | yes | re-entered through feature-reentry after round 1 (CLARIFY): AZ-2733, four workers on disjoint paths |
| feature-assess | 10.5 | Feature Assessment | yes | this loop's work; read-only, writes `assessment45.md` and appends `scenarios.md` rows |
| run-tests | 11 | Run Tests | yes | one run at HEAD; stages with unchanged inputs are skipped |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario of the suite specs changes |
| update-docs | 13 | Update Docs | no | no contract changes |
| security | 14 | Security Audit | no | report dated 2026-10-19; no untrusted-input path changes |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | due after loop 45; owner-run |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke45.md` |

## Implementation
### Files that change
- `_docs/loops/loop45/assessment45.md` (new), `_docs/02_task_plans/compact-strings/scenarios.md` and `_docs/02_task_plans/message-error-correction/scenarios.md` (appended rows, source `assess-round-1`), loop record and smoke. No source, spec or test file.
### Order of work
Two read-only analysts in parallel (one per feature) return coverage matrices to the scratchpad; the parent spot-checks the cited AC, test and code path of a sample and of every non-`covered` row, merges, sets the verdict, writes the report. Then step 11, smoke, close, push `dev` and `main`.
### Proof
Report header and first chat line carry the verdict; every `covered` row cites AC + test + code path; every `gap-clear` row quotes its basis.
### Risks
Wide scope (cap of 12 new rows per round, rest under `## Not walked`). A non-COMPLETE verdict adds specs and a code pass in this loop.

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY | AZ-2733_assessment45_gaps | _docs/loops/loop45/assessment45.md |

Owner 2026-10-20 answered the six cards (accept all recommended) and chose "small items now, tests next loop": the rest (CS-S3, CS-A5/A10, CS-D7, EC-D2) goes to `handoff46.md`; CS-D5 waits for the owner's real messages. Step 11 runs once after the implement pass; the second assessment round is not run (owner rule 2026-10-06: no growing chain of rounds), the open rows are recorded in the loop record.
