# Autodev Loop Plan — Loop 21

loop: 21
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: `_docs/loops/loop21/handoff21.md`; problem: `_docs/02_task_plans/parity-rules-and-round-cpu-bound/`. Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`, `decision-batches-accept-recommended`): workers run only their own package suite; no per-batch review and no per-batch Docker run (C++ keeps its `gcc:16` and arm checks); one total review and one step-11 run at the end; no chained feature-assess rounds (open angles go to the loop 22 handoff); shell-hygiene paragraph, the index-write ban and "no formatter on files you do not own" in every worker prompt; the Go package (AZ-2222) is the next loop.

## Owner decisions (2026-10-12, "accept all recommended")

| # | Decision | Taken |
|---|----------|-------|
| 1 | U1 Python unpack slot surcharge | A: align → AZ-2381 |
| 2 | U2 slot width of a round | A: TypeScript rule in six → AZ-2382 |
| 3 | U3 short list in optional flags | A: refuse everywhere → AZ-2383 |
| 4 | U4 split-bit `times`, absent body | A: pack a clear bit everywhere → AZ-2384 |
| 5 | U5 C++ late `when` in a bit body | A: pack if no flash cost → AZ-2385 |
| 6 | U6 count 1 behind a clear `when` | A: refuse everywhere → AZ-2386 |
| 7 | U7 `bits`/`packed`/`sized` behind a clear `when` | A: probe four, align → AZ-2387 |
| 8 | U8 typed C# rounds | A: bind to rows → AZ-2388 |
| 9 | U9 C# dict member in a round | A: refuse at build → AZ-2389 |
| 10 | U10 message/limit parity | B: accept (upgrade-note line, step 13) |
| gaps | AZ-2373, F33, F34, G2–G4, A7 | AZ-2373, AZ-2390 to AZ-2393; hostile cases AZ-2394 |

## Scope

Specs claimed (`loop: 21`): AZ-2373, AZ-2381 to AZ-2394 (42 points). AZ-2068 (C++ AVR stretch) stays out.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | specs are 2 to 5 points |
| implement | 10 | Implement | yes | three waves, see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 22 handoff, no re-entry round |
| run-tests | 11 | Run Tests | yes | one total run: six package suites, hostile vectors, golden, rings, embedded stages (cpp changes) |
| test-spec-sync | 12 | Test-Spec Sync | yes | hostile set gains the loop 21 `pack` cases; ACs L1–L11 enter the matrix |
| update-docs | 13 | Update Docs | yes | README limits (one slot rule, `maxBytes` memory bound), upgrade notes (U3, U6, U7, F33 refusals, C# integer types, U10 text) |
| security | 14 | Security Audit | yes | F33, F34 should close; empty-body refusal is a new input check |
| performance | 15 | Performance Test | no | AZ-2391 timing is a unit test |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag needs the owner's go |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 42 points across six packages |
| local-deploy | — | Local deploy + open site | yes | no site: package suites and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | one-paste script in `smoke21.md`, run by the agent (owner rule in `deployment_procedures.md`) |

## Implementation

### Files that change

One worker per package directory owns that directory (sources, tests): `typescript/`, `cpp/`, `csharp/`, `python/`, `java/`, `rust/`. The TypeScript worker also writes `_docs/03_implementation/reference_loop21_slots.md` (only that file under `_docs/`). Wave 2 owns `fixtures/hostile/**` (one worker), then the four loader workers (python, java, rust, cpp test files). Parent-only: every other `_docs/**` file, `README.md`, tracker, commits.

### Order of work

1. **Wave 1a** (parallel, three workers):
   - `typescript/` (reference): AZ-2382 → reference table → AZ-2390 (rule + text into the table) → AZ-2383 → AZ-2391 → pin AZ-2384/AZ-2386/AZ-2387 (probe rows into the batch report).
   - `cpp/`: AZ-2385 (flash gate) → AZ-2390 C++ share after the reference → arm stage numbers.
   - `csharp/`: AZ-2373 → AZ-2389 → AZ-2388 → AZ-2393.
   - Parent: check every AC of AZ-2382/AZ-2390 against the reference rows; amend the specs before wave 1b.
2. **Wave 1b** (parallel, four workers, after the reference check): `python/` (AZ-2381, AZ-2382, AZ-2383 probe, AZ-2386, AZ-2387, AZ-2390), `java/` (AZ-2382, AZ-2383 probe, AZ-2384, AZ-2387, AZ-2390), `rust/` (AZ-2382, AZ-2383/AZ-2384 probe, AZ-2387, AZ-2390), `csharp/` second pass (AZ-2382, AZ-2383/AZ-2384/AZ-2386 probe, AZ-2387, AZ-2390).
3. **Wave 2**: AZ-2394 (`fixtures/hostile/**`), then AZ-2392 (four loaders, one worker per directory).
4. **Parent, once**: one total review, one step-11 run, feature-assess (read-only), steps 12–14 and 17, smoke, close, push `dev`, fast-forward `main`, watch CI.

### Proof

Each worker's package suite green; the arm embedded stage within 8 192 B flash / 512 B stack (AC-L4); the step-11 run covers the six suites, the hostile set, golden, route and ring fixtures.

### Risks

Flash margin 32 B (AZ-2385, AZ-2390 in C++); the reference table must be checked before wave 1b; csharp is touched in both wave 1a and 1b, so its two passes never overlap.
