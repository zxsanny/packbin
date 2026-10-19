# Autodev Loop Plan — Loop 42

loop: 42
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-19) took "accept all recommended": AZ-2713 (strictly ascending dict keys in all eight packages, F51 and F56) plus AZ-2722 (the cheap loop 41 Lows F57, F59, F60 and the F19 instances in Python and TypeScript); F58 (Python session pad) deferred; `main` fast-forward at close per `ci_cd_pipeline.md`. Epic AZ-2645.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in todo/ (AZ-2713, AZ-2722) |
| decompose-feature | 9.5 | Decompose Feature | no | per-package edits are small; the parent splits them across at most 4 workers with disjoint files |
| implement | 10 | Implement | yes | AZ-2713, AZ-2722 |
| feature-assess | 10.5 | Feature Assessment | no | short loop; owner-run skill, carried |
| run-tests | 11 | Run Tests | yes | one step 11 run for the loop, plus the arm embedded stage (C++ core edit) |
| test-spec-sync | 12 | Test-Spec Sync | no | the new hostile cases are in `fixtures/hostile/` |
| update-docs | 13 | Update Docs | no | contract, README and security report inside the tasks |
| security | 14 | Security Audit | no | /security (AZ-2666 follow-up) owner-run; report addendum updated in the tasks |
| performance | 15 | Performance Test | no | AC-3 of AZ-2713 is a test |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | owner-run, carried |
| local-deploy | — | Local deploy + open site | yes | none (library; CI is the proof) |
| smoke | — | Smoke acceptance | yes | script in `smoke42.md`, agent run per `deployment_procedures.md` |

## Implementation
### Files that change
- Contract `compact-text.md`, `README.md`, `fixtures/hostile/{cases.txt,README.md}` (parent, at intake and close).
- Per package, workers own disjoint trees: Python + TypeScript; C# + Java; Rust + Go; Swift; C++ in the parent. Each: the dict decoder, its tests (hostile replay handlers for the five new cases, a byte-order test, a 65,535-key speed test).
- AZ-2722: C++ `session.hpp`/`codec.hpp` (parent), C# and Go repair, Rust text decoder, Python and TypeScript session.
### Order of work
Intake commit (cases + specs), then workers per package in parallel, parent does C++; each package's own suite; one total review; step 11 (`scripts/loop-tests.sh`) once; smoke script; close; push `dev` and `main`.
### Proof
AC-1 to AC-4 of AZ-2713; AC-1 to AC-5 of AZ-2722.
### Risks
C++: unbound dict has no key storage; the Cortex-M4F flash (60 B) and stack (20 B) margins; Java, C# and TypeScript string order is UTF-16, the rule is UTF-8 byte order.
