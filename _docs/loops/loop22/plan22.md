# Autodev Loop Plan — Loop 22

loop: 22
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: `_docs/loops/loop22/handoff22.md`; problem: `_docs/02_task_plans/parity-rules-and-memory-bound/`. Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`, `decision-batches-accept-recommended`): workers run only their own package suite; no per-batch review and no per-batch Docker run (C++ keeps its `gcc:16` and arm checks); one total review and one step-11 run at the end; no chained feature-assess rounds (open angles go to the loop 23 handoff); shell-hygiene paragraph, the index-write ban and "no formatter on files you do not own" in every worker prompt; the Go package (AZ-2222) is the next loop.

## Owner decisions (2026-10-12, "accept all recommended")

| # | Decision | Taken |
|---|----------|-------|
| 1 | U11 no-value count behind a clear `when` | A: refuse in six → AZ-2410 |
| 2 | U12 C# float list for integer list | A: refuse at construction → AZ-2411 |
| 3 | U13 Rust repeat lists without groups | A: refuse → AZ-2412 |
| 4 | U14 Python unequal repeat lists | A: align Python → AZ-2413 |
| 5 | U15 short `times` list under `flags` | B: accept in all → AZ-2414 (Rust) |
| 6 | U16 nested-row group slot count | B: README exception, Go copies TypeScript (step 13) |
| 7 | U17 default `maxSlots` | A: lower (1 048 576) → AZ-2415 |
| gaps | G1, loader checks, hostile cases | AZ-2416, AZ-2418, AZ-2417 |

## Scope

Specs claimed (`loop: 22`): AZ-2410 to AZ-2418 (21 points). AZ-2068 (C++ AVR stretch) stays out.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | specs are 2 to 3 points |
| implement | 10 | Implement | yes | three waves, see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 23 handoff, no re-entry round |
| run-tests | 11 | Run Tests | yes | one total run: six package suites, hostile vectors, golden, rings, embedded stages |
| test-spec-sync | 12 | Test-Spec Sync | yes | hostile set gains the loop 22 cases |
| update-docs | 13 | Update Docs | yes | README limits (new default), upgrade notes (U11, U12, U13, U14, U15), U16 exception |
| security | 14 | Security Audit | yes | F10 should close; new refusals are input checks |
| performance | 15 | Performance Test | no | AZ-2415 memory A/B is a measured report inside the task |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag needs the owner's go |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 21 points across six packages |
| local-deploy | — | Local deploy + open site | yes | no site: package suites and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | one-paste script in `smoke22.md`, run by the agent (owner rule in `deployment_procedures.md`) |

## Implementation

### Files that change

One worker per package directory owns that directory (sources, tests): `typescript/`, `cpp/`, `csharp/`, `python/`, `java/`, `rust/`. The TypeScript worker also writes `_docs/03_implementation/reference_loop22.md` (only that file under `_docs/`). Wave 2 owns `fixtures/hostile/**` (one worker), then the loader workers (python, java, rust, cpp, typescript, csharp test files). Parent-only: every other `_docs/**` file, `README.md`, tracker, commits.

### Order of work

1. **Wave 1a** (parallel, four workers):
   - `typescript/` (reference): AZ-2410 → AZ-2415 → probe rows for AZ-2413/AZ-2414 (TypeScript bytes) → reference table.
   - `cpp/`: AZ-2416 (flash gate, arm stage).
   - `csharp/`: AZ-2411.
   - `rust/`: AZ-2412.
   - Parent: check every AC of AZ-2410/AZ-2413/AZ-2414/AZ-2415 against the reference rows; amend the specs before wave 1b.
2. **Wave 1b** (parallel, up to four workers at a time, after the reference check): `python/` (AZ-2413, AZ-2410, AZ-2415), `java/` (AZ-2410, AZ-2415, AZ-2413 probe), `csharp/` second pass (AZ-2410, AZ-2415, AZ-2413 probe), `rust/` second pass (AZ-2414, AZ-2410, AZ-2415), then `cpp/` second pass (AZ-2410 share, limit probe).
3. **Wave 2**: AZ-2417 (`fixtures/hostile/**`), then AZ-2418 plus the loader tables (one worker per directory).
4. **Parent, once**: one total review, one step-11 run, feature-assess (read-only), steps 12–14 and 17, smoke, close, push `dev`, fast-forward `main` if the project `loop_end_merge` says so, watch CI.

### Proof

Each worker's package suite green; the arm embedded stage within 8 192 B flash / 512 B stack; the step-11 run covers the six suites, the hostile set, golden, route and ring fixtures.

### Risks

Flash margin 40 B (AZ-2416, AZ-2410 in C++); the reference table must be checked before wave 1b; csharp and rust are touched in both wave 1a and 1b, so their two passes never overlap; AZ-2415 changes message texts and thresholds in many tests.
