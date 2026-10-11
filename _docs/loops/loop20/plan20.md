# Autodev Loop Plan — Loop 20

loop: 20
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: `_docs/loops/loop20/handoff20.md`; problem: `_docs/02_task_plans/pack-output-budget-and-parity/`. Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`, `decision-batches-accept-recommended`): workers run only their own package suite; no per-batch review and no per-batch Docker run (C++ keeps its `gcc:16` and arm checks); one total review and one step-11 run at the end; no chained feature-assess rounds (open angles go to the loop 21 handoff); shell-hygiene paragraph and the index-write ban in every worker prompt; the Go package (AZ-2222) is the next loop.

## Owner decisions (2026-10-11, "accept all recommended")

| # | Decision | Taken |
|---|----------|-------|
| 1 | F28 pack output budget | A: `maxBytes` per pack call (16 MiB default) + `maxSlots` per round on pack → AZ-2354, before Go |
| 2 | U1 `repeat` above `maxRounds` on pack | A → AZ-2355 |
| 3 | U2 count 0 after the byte with values | A: error with a list in six, lone scalar silent → AZ-2356 |
| 4 | U3 absent `when` source in a split bit | A: keep (no code; upgrade-note text, step 13) |
| 5 | U4 C++ count behind a clear `when` | A: fix → AZ-2357 |
| 6 | U5 whole-number floats | A: refuse except JavaScript → AZ-2358 (C#) |
| 7 | U6 enums as slot values | A: integer enum accepted where the language treats it as an int, C# unchanged → AZ-2359 |
| 8 | U7 C++ `eq(u8, true)` | A: leave and document (step 13) |
| 9 | B6 combined `flags` skipped count with values | A: loud in six → AZ-2360 |
| gaps | G1–G5, F17/F27, F29/F30 | AZ-2361 to AZ-2366; hostile cases AZ-2367 |

## Scope

Specs claimed (`loop: 20`): AZ-2354 to AZ-2367 (25 points). AZ-2068 (C++ AVR stretch) stays out.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | specs are 1 to 5 points |
| implement | 10 | Implement | yes | three waves, see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 21 handoff, no re-entry round |
| run-tests | 11 | Run Tests | yes | one total run: six package suites, hostile vectors, golden, rings, embedded stages (cpp changes) |
| test-spec-sync | 12 | Test-Spec Sync | yes | hostile set gains the budget and parity `pack` cases; the loop 19 interaction risks become ACs |
| update-docs | 13 | Update Docs | yes | README limits (`maxBytes`, slots on pack, `repeat` cap), upgrade notes for decisions 1 to 9 (U3, U7 text), stale docs from `ripple_log_loop19.md` |
| security | 14 | Security Audit | yes | F28, F31, F17, F27, F29, F30 should close |
| performance | 15 | Performance Test | no | no throughput AC (AZ-2354 AC-1 time bound is a unit test) |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag needs the owner's go |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 25 points across six packages |
| local-deploy | — | Local deploy + open site | yes | no site: package suites and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | one-paste script in `smoke20.md` |

## Implementation

### Files that change

One worker per package directory owns that directory (sources, tests): `typescript/`, `cpp/`, `csharp/`, `python/`, `java/`, `rust/`. The TypeScript worker also writes `_docs/03_implementation/reference_loop20_budget.md` (only that file under `_docs/`). Wave 2 (one worker) owns `fixtures/hostile/**`; the six hostile loaders' test files are edited only if a stage name is new. Parent-only: every other `_docs/**` file, `README.md`, tracker, commits.

### Order of work

1. **Wave 1a** (parallel, two workers):
   - `typescript/` (reference): AZ-2354 → AZ-2355 → reference table → AZ-2356 → AZ-2360 → AZ-2363 → AZ-2359 (pin).
   - `cpp/`: AZ-2357 → AZ-2364 → AZ-2356 → AZ-2360 (pin) → arm stage numbers.
   - Parent: check every AC of AZ-2354/AZ-2355 against the reference rows; amend the specs before wave 1b.
2. **Wave 1b** (parallel, four workers, against the reference table):
   - `csharp/`: AZ-2365 (LayoutTests split) → AZ-2354 → AZ-2355 → AZ-2366 → AZ-2358 → AZ-2360 → AZ-2356 (pin) → AZ-2359 (pin).
   - `python/`: AZ-2354 → AZ-2355 → AZ-2362 → AZ-2356 → AZ-2360 (pin) → AZ-2359 (pin).
   - `java/`: AZ-2361 → AZ-2354 → AZ-2355 → AZ-2356 → AZ-2360 → AZ-2359 (pin).
   - `rust/`: AZ-2365 (bound.rs split) → AZ-2354 → AZ-2355 → AZ-2360 → AZ-2356 (pin) → AZ-2359 (pin).
3. **Wave 2** (one worker): AZ-2367 hostile cases and loaders.
4. Then: one total review, step 11 run, feature-assess, docs, security, retrospective, close, push, CI watch.

Each worker returns a status table and a `## Discovered during implementation` list; the parent checks `git diff --cached` (must stay empty) and the diff scope after each worker, writes `batch_NN_loop20_report.md`, and commits locally per wave.

### Proof

Per package: the package suite only (no Docker). C# on net10.0 and `-p:PackbinTarget=netstandard2.0`, with `env MSBUILDDISABLENODEREUSE=1`. C++: `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` plus the arm embedded stage for `cpp/src/core`. Python: a per-worker venv with Python 3.10+. Wire bytes of accepted rows do not change.

### Risks

- The budget check sits on the hot append path: one comparison per append, no allocation; AZ-2354 AC-1 bounds time and memory.
- Cortex-M4F flash margin 128 B against about 56 B for AZ-2357 plus AZ-2364: the C++ worker stops below 32 B.
- A worker that finds its package already differs from the reference reports it before changing the reference behavior.
