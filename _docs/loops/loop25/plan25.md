# Autodev Loop Plan — Loop 25

loop: 25
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: `_docs/loops/loop25/handoff25.md` (owner batch 2026-10-14: D1-D7 recommended A, F44 owner-applied before any Go tag; short wave U25 A, U26 A, Low-1 A; U24 B README-only; D8 Go peak memory). Prior loop: `_docs/loops/loop24/plan24.md`, `review24.md`, `assessment24.md`. Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`, `decision-batches-accept-recommended`): workers run only their own suite; no per-batch review or Docker run; one total review and one step-11 run at the end (check `uptime` and swap first); no chained feature-assess rounds; shell-hygiene paragraph, index-write ban and "no formatter on files you do not own" in every worker prompt.

## Scope

Specs claimed (`loop: 25`): AZ-2452 to AZ-2459 (8 specs, ~14 points). AZ-2068 stays out. F44 (owner-only) tracked in handoff.

| id | points | component | source |
|----|--------|-----------|--------|
| AZ-2452 | 3 | cpp | U25 A (hostile constructs; builder id-range check) |
| AZ-2453 | 2 | csharp | U26 A (dictionary rows read nested-row names from nested dict) |
| AZ-2454 | 1 | python | Low-1 A (ValueError text for value with no count-writing field) |
| AZ-2455 | 1 | go, docs | D8 (peak memory for F10 and wide-round packets, loop 22 table + README) |
| AZ-2456 | 1 | all seven, docs | D1 A (probe the other four for anchor-group-with-no-takers; document) |
| AZ-2457 | 2 | six | D6 A (align the six to Go on `run-suite.sh`: missing manifest fails) |
| AZ-2458 | 3 | six | D7 A (probe the six for split-flag-in-false-when; fix outliers) |
| AZ-2459 | 1 | docs | U24 B (README note: C++ clear bit for unbound member) |

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` + `/new-task` ran at intake (handoff decided scope) |
| decompose-feature | 9.5 | Decompose Feature | no | done at intake: scope table above and `## Implementation` |
| implement | 10 | Implement | yes | one or two waves, see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 26 handoff |
| run-tests | 11 | Run Tests | yes | one total run: seven suites, hostile, golden, ring, publish-gate tests |
| test-spec-sync | 12 | Test-Spec Sync | yes | traceability rows for the new AC |
| update-docs | 13 | Update Docs | yes | README (U24, D8), parity row docs (D1 and D7 outcomes), AC-15/D6 wording |
| security | 14 | Security Audit | yes | hostile vector changes and the `run-suite.sh` behavior change |
| performance | 15 | Performance Test | no | no new perf NFR (D8 is a measurement, not a bound) |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | the first Go tag needs the owner's go with the exact commit AND F44 applied |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | ~14 points; closes the Go epic's prerequisites |
| local-deploy | — | Local deploy + open site | yes | no site: suites, ring and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | one-paste script in `smoke25.md`, run by the agent |

## Implementation

### Files that change (ownership tiers)

- `cpp/**` has one writer at a time (AZ-2452 only; `cpp/src/*` and `cpp/include/*` → arm embedded stage required; margin 40 B at loop 24 close).
- `csharp/**` has one writer at a time (AZ-2453 only).
- `python/**` has one writer at a time (AZ-2454 only).
- `go/**` has one writer at a time (AZ-2455 only; tests + a memory-measurement helper file).
- Multi-package touches (own only that package's tree): AZ-2456 probes six packages (`python/`, `rust/`, `java/`, `csharp/`, `cpp/`, cannot run `go/`) and may write a parity row doc; AZ-2457 touches `run-suite.sh` for each of the six (`typescript/`, `python/`, `rust/`, `csharp/`, `java/`, `cpp/`) and `_docs/02_task_plans/pack-output-budget-and-parity/` where AC-15 wording lives; AZ-2458 probes and may fix a walker in the outliers.
- Parent-only: `_docs/**` (incl. README), tracker, commits, `_docs/02_task_plans/**` acceptance text.

### Order of work (one wave; subagents run disjoint files in parallel)

Wave 1 — four single-package tasks run in parallel (`subagents.md` cap 4):
- AZ-2452 (cpp hostile constructs; arm stage)
- AZ-2453 (csharp dict row names)
- AZ-2454 (python ValueError)
- AZ-2455 (go memory measurement)

Wave 2 — three multi-package or decision tasks, run after wave 1 since the walker fixes AZ-2458 names may touch files that overlap with earlier work; D1 (AZ-2456) and U24 (AZ-2459) are documentation-only and may run in parallel with D7 (AZ-2458):
- AZ-2456 (D1 probe + document; owns `_docs/02_task_plans/round-parity-and-construction-checks/` parity rows notes)
- AZ-2457 (D6 align six to Go; owns `typescript/run-suite.sh` wrapper and the five others' manifests under `*/run-suite.sh`; AC-15 wording)
- AZ-2458 (D7 probe six; may fix a walker in one or two outliers)
- AZ-2459 (U24 README edit; owns `README.md` C++ clear-bit paragraph)

Non-interactive subagent commands (memory `noninteractive-subagent-commands`): every worker shell block ends on its own with `< /dev/null` and a `timeout`. The parent checks `git diff --cached` after each join and refuses any index write a worker did.

### Smoke script

`_docs/loops/loop25/smoke25.md` is the one-paste bash script, trial-run before close. The agent runs it at the commit before close and auto-passes the gate when every step is PASS (memory `smoke-one-paste-script`). First step must find a clean tree.

### Totals

8 specs, ~14 points. Workers write tests first (one AC pin per outcome) and run only their own suite (memory `one-total-review-and-test`). One total review + one total `test-run` at the end.
