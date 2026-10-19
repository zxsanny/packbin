# Autodev Loop Plan — Loop 43

loop: 43
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-19) took "accept all recommended" after loop 42: the load-aware timing bounds (retro action 2, AZ-2723) and F58 (Python session pad, AZ-2724); AZ-2068 stays out; `main` fast-forward at close per `ci_cd_pipeline.md`. Epic AZ-2645.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in todo/ |
| decompose-feature | 9.5 | Decompose Feature | no | test-only helpers per package and one small Python change |
| implement | 10 | Implement | yes | AZ-2723, AZ-2724 |
| feature-assess | 10.5 | Feature Assessment | no | owner-run, carried |
| run-tests | 11 | Run Tests | yes | one run for the loop |
| test-spec-sync | 12 | Test-Spec Sync | no | none |
| update-docs | 13 | Update Docs | no | one contract sentence and one gotcha line inside the tasks |
| security | 14 | Security Audit | no | F58 fixed in the report update inside the task |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | owner-run |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke43.md` |

## Implementation
### Files that change
- AZ-2723: test files of each package (one helper file each) and the timing assertions that use it; `_docs/AGENT_GOTCHAS.md`. Workers by package: Python + TypeScript, C# + Java, Rust + Go, Swift + C++. No production code.
- AZ-2724 (parent): `python/src/packbin/_scheme.py` (`_receive`), `_session.py`, a new Python test, `pack-session.md`, README, security report.
### Order of work
Intake commit, workers in parallel, the parent does AZ-2724; each package's suite idle and under 12 busy processes; one total review; step 11; smoke; close; push `dev` and `main`.
### Risks
The idle-host calibration constant is measured while the host is loaded by other sessions: use the smallest of many runs. JIT languages (Java, C#, TypeScript) need a warm-up inside the reference loop.
