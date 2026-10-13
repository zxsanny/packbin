# Autodev Loop Plan — Loop 23

loop: 23
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: `_docs/loops/loop23/handoff23.md`; problem: `_docs/02_task_plans/parity-rows-u19-to-u23/`. Loop number 23: the `loop23/` folder held only the handoff written at the loop 22 close; no plan or record existed, so N is not reused. Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`, `decision-batches-accept-recommended`): workers run only their own package suite; no per-batch review and no per-batch Docker run (C++ keeps its `gcc:16` and arm checks); one total review and one step-11 run at the end (check `uptime` and swap first); no chained feature-assess rounds; shell-hygiene paragraph, the index-write ban and "no formatter on files you do not own" in every worker prompt; the Go package (AZ-2222) is the next loop.

## Owner decisions (2026-10-13, "accept all recommended")

| # | Decision | Taken |
|---|----------|-------|
| 1 | U18 Rust list for a member under a `when` inside a `times` | B: README exception, repack from groups (step 13) |
| 2 | U19 C++ negative `eq` source id | A: refuse at construction, flash-gated → AZ-2431 |
| 3 | U20 C++ `packed` bias -1 refused in the U11 grid | A: trace, README exception if typed row → AZ-2432 |
| 4 | U21 `construct_empty_*when*` cases refused by the scope rule first | A: keep; README says which rule fires per package (step 13) |
| 5 | U22 Rust repeat drops values in two shapes | A: refuse both → AZ-2433 |
| 6 | U23 TypeScript bigint count above 2^53 | A: refuse → AZ-2434 |
| gaps | G1, G2, G3 | AZ-2435, AZ-2431 (G2), AZ-2436 |

## Scope

Specs claimed (`loop: 23`): AZ-2431 to AZ-2436 (10 points), plus AZ-2437 (Python bug found in the batch, 1 point). AZ-2068 (C++ AVR stretch) stays out.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | specs are 1 to 2 points |
| implement | 10 | Implement | yes | one wave, see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 24 handoff, no re-entry round |
| run-tests | 11 | Run Tests | yes | one total run: six package suites, hostile vectors, golden, rings, embedded stages |
| test-spec-sync | 12 | Test-Spec Sync | yes | traceability rows for AZ-2431 to AZ-2436 |
| update-docs | 13 | Update Docs | yes | README: U18 exception and repack-from-groups note, U19/U22/U23 upgrade notes, U20 outcome, U21 hostile README text |
| security | 14 | Security Audit | yes | F36 and F37 should close; new refusals are input checks |
| performance | 15 | Performance Test | no | no limit or hot-path change |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag needs the owner's go |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | every task at most 2 points, no incident, retro ran in loop 22 |
| local-deploy | — | Local deploy + open site | yes | no site: package suites and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | one-paste script in `smoke23.md`, run by the agent (owner rule in `deployment_procedures.md`) |

## Implementation

### Files that change

One worker per package directory owns that directory (sources, tests): `cpp/` (AZ-2431 then AZ-2432, G3 C++ share), `rust/` (AZ-2433, AZ-2435 Rust share, G3 Rust share), `typescript/` (AZ-2434, G3 TypeScript share), `python/` (AZ-2435 Python share, G3 Python share), then `java/` and `csharp/` (G3 shares). Parent-only: every `_docs/**` file, `README.md`, `fixtures/**`, tracker, commits.

### Order of work

1. **Wave 1a** (parallel, four workers): `cpp/`, `rust/`, `typescript/`, `python/`.
2. **Wave 1b** (parallel, two workers, as wave 1a slots free): `java/`, `csharp/` (AZ-2436 only).
3. **Parent, once**: one total review, feature-assess (read-only), one step-11 run, steps 12–14, smoke, close, push `dev`, fast-forward `main` per the project `loop_end_merge`, watch CI.

As run: wave 1a `cpp/`, `rust/`, `typescript/`, `python/`; wave 1b `java/`, then `csharp/`; the Python worker was resumed for AZ-2437 (owns `python/src/packbin/` U11 check) when the Java slot freed. AZ-2433 AC-1 and AZ-2436 AC-2 amended during the batch (see the specs).

### Proof

Each worker's package suite green; C++ host, `gcc:16` and arm embedded stage within 8 192 B flash / 512 B stack; the step-11 run covers the six suites, the hostile set, golden, route and ring fixtures.

### Risks

Flash margin 40 B (AZ-2431, AZ-2432 if aligned); AZ-2436 may find a package that packs where U11 says refuse (reported, not fixed in the task); AZ-2435 tests allocate several hundred MB and flaked under host load in loop 22.
