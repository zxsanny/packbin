# Autodev Loop Plan — Loop 47

loop: 47
kind: product
confirmed: true
branch: dev
ship: false

Intake: hopper hit. The loop 46 record leftovers and `handoff47.md` hold the rows; the owner chose "accept all recommended" on 2026-10-20: CI-split (AZ-2744) and TSan (AZ-2745). AZ-2742 (C++ shortcut, 3 points; needs a flash and stack saving and the arm embedded stage) is left out by that choice. Epic AZ-2645. No interview.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at intake: two specs, two Jira tasks (5 points) |
| decompose-feature | 9.5 | Decompose Feature | no | 5 points in two atomic tasks |
| implement | 10 | Implement | yes | one batch, two workers with disjoint files |
| feature-assess | 10.5 | Feature Assessment | no | CI scripts only; loop 46 review named both rows |
| run-tests | 11 | Run Tests | yes | one run at HEAD; unchanged stages skipped |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario of the product changes |
| update-docs | 13 | Update Docs | no | no contract change |
| security | 14 | Security Audit | no | report dated 2026-10-19; scripts only |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | 1 loop since `retro_2026-10-20_loop46.md`, no incident |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke47.md` |

## Implementation

### Files that change
- AZ-2744: `.github/workflows/language-pair.sh`, new `ring-lib.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `ring-ecc.sh`, `ring-prepare.test.sh`, a new session-ecc wiring test (and `test.yml` only if it names a moved file).
- AZ-2745: `.github/workflows/run-suite.sh`, `run-suite-swift.test.sh`.

### Order of work
Tracker In Progress; two workers in parallel (CI ring, Swift suite script), each runs only its own scripts' tests; the Swift TSan run is the only `swift test` in the root tree. Then one total review, one step 11 run, smoke, close, push `dev` and `main`.

### Proof
Each wiring and suite test green with its mutants; the ring prints "language pairs passed"; `swift test --sanitize=thread` on `TextConcurrencyTests` passes; step 11 once at HEAD.

### Risks
TSan finds a real race: stop and report. A reader of the ring lines missed: found by `git grep` and step 11. The Mac load makes the ring and Swift runs slow: status line every 30 s.

## Assessment rounds

None.
