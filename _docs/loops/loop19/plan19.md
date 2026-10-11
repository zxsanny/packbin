# Autodev Loop Plan — Loop 19

loop: 19
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree; the five old `loop/*` worktrees are idle legacy). Intake: `_docs/loops/loop19/handoff19.md`; problem: `_docs/02_task_plans/round-parity-and-construction-checks/`. Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`, `decision-batches-accept-recommended`): workers run only their own package suite; no per-batch review and no per-batch Docker run; one total review and one step-11 run at the end; no chained feature-assess rounds (open angles go to the loop 20 handoff); shell-hygiene paragraph and the index-write ban in every worker prompt; the Go package (AZ-2222) is loop 20.

## Owner decisions (2026-10-11, "accept all recommended")

| # | Decision | Taken |
|---|----------|-------|
| 1 | Pack round cap F21 | A: cap at `maxRounds` (65 535) in five packages → AZ-2329 |
| 2 | Python round scope | A: fresh scope per round → AZ-2330 |
| 3 | Split-form silent drop | A: pack fails loudly, six packages → AZ-2331 |
| 4 | Lone byte buffer in a round | A: refuse everywhere → AZ-2332 |
| 5 | Sibling flags scope | A: change Rust → AZ-2333 |
| 6 | C++ empty group as `when` source | A: accept → AZ-2334 |
| 7 | `times` count 0 with values | A: error everywhere → AZ-2335 |
| 8 | Python short `times` list | A: named error → AZ-2336 |
| 9 | C# group element | A: members only → AZ-2337 |
| 10 | C# member-type set | A: keep the refusal (upgrade-note text, step 13) |
| 11 | `eq` value at construction | A: refuse in six → AZ-2338 |
| 12 | Ring shape | A: keep the chain (no work) |
| 13 | Fractions in u2/bits/packed | A: probe → AZ-2339 |
| scope | hopper + clear gaps | AZ-2340, AZ-2341, AZ-2342; Go is loop 20 |

## Scope

Specs claimed (`loop: 19`): AZ-2329 to AZ-2342 (26 points). AZ-2068 (C++ AVR stretch) stays out; its stale loop 10 claim was cleared at intake.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | specs are 1 to 3 points |
| implement | 10 | Implement | yes | two waves, see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 20 handoff, no re-entry round |
| run-tests | 11 | Run Tests | yes | one total run: six package suites, hostile vectors, golden, rings, embedded stages (cpp changes) |
| test-spec-sync | 12 | Test-Spec Sync | yes | hostile set gains `pack`/`construct` cases; catch-up of loops 11 to 18 where cheap |
| update-docs | 13 | Update Docs | yes | README upgrade notes (decisions 1 to 11), decisions 10 and 12 text |
| security | 14 | Security Audit | yes | F21 closes; pack stage and construction checks in six packages |
| performance | 15 | Performance Test | no | no throughput AC |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag needs the owner's go |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 26 points across six packages |
| local-deploy | — | Local deploy + open site | yes | no site: package suites and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | one-paste script in `smoke19.md` |

## Implementation

### Files that change

One worker per package directory owns that directory (sources, tests): `csharp/`, `typescript/`, `python/`, `java/`, `rust/`, `cpp/`. Wave 2 (one worker) owns `fixtures/hostile/**`, the six hostile loaders' test files are edited by the package workers in wave 2 only if the loader needs a new stage name, and `run-suite.sh` (AZ-2341). Parent-only: `_docs/**`, `README.md`, tracker, commits.

### Order of work

1. **Wave 1** (parallel, cap 4: csharp, rust, python, java first; typescript, cpp when one finishes). Per worker, in this order:
   - `csharp/`: AZ-2342 (split) → AZ-2329 → AZ-2331 → AZ-2337 → AZ-2338 → AZ-2335 → AZ-2332 (test only).
   - `rust/`: AZ-2342 → AZ-2329 → AZ-2331 → AZ-2333 → AZ-2332 → AZ-2335 → AZ-2338 → AZ-2339 (probe).
   - `python/`: AZ-2330 → AZ-2329 → AZ-2331 → AZ-2332 → AZ-2335 → AZ-2336 → AZ-2338 → AZ-2339.
   - `java/`: AZ-2342 → AZ-2329 → AZ-2331 → AZ-2332 → AZ-2335 → AZ-2338 → AZ-2339.
   - `typescript/`: AZ-2329 → AZ-2331 → AZ-2332 → AZ-2335 → AZ-2338 → AZ-2339.
   - `cpp/`: AZ-2331 → AZ-2334 → AZ-2335 → AZ-2338 → AZ-2339 → AZ-2340.
2. **Wave 2** (one worker, after wave 1): hostile cases `pack_times_count_over_limit`, the AZ-2331 shapes, `pack_times_zero_with_values`, `construct_eq_out_of_range`, README of the hostile set, `check-cases.sh`, six loaders; AZ-2341.
3. Then: one total review, step 11 run, feature-assess, docs, security, retrospective, close, push, CI watch.

Each worker returns a status table and a `## Discovered during implementation` list; the parent checks `git diff --cached` (must stay empty) and the diff scope after each worker, writes `batch_NN_loop19_report.md`, and commits locally per wave.

### Proof

Per package: the package suite only (no Docker). C# on net10.0 and `-p:PackbinTarget=netstandard2.0`, with `env MSBUILDDISABLENODEREUSE=1`. C++: `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` plus the arm embedded stage for `cpp/src/core`. Python: a per-worker venv. Wire bytes of accepted rows do not change except the Python and Rust rows of AZ-2330 and AZ-2333.

### Risks

- AZ-2331 and AZ-2335 may differ per package; each worker probes first.
- Cortex-M4F stack margin 56 B (AZ-2334).
- Python and Rust byte changes need upgrade notes.
