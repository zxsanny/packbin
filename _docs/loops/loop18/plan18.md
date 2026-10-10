# Autodev Loop Plan — Loop 18

loop: 18
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree; the five old `loop/*` worktrees are idle legacy). Intake: `_docs/loops/loop18/handoff18.md`. Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`): workers run only their own package suite; no per-batch review and no per-batch Docker run; one total review and one step-11 run at the end; no chained feature-assess rounds (open angles go to the loop 19 handoff); shell-hygiene paragraph and the index-write ban in every worker prompt; the Go package (AZ-2222) is loop 19.

## Owner decisions (2026-10-10, "accept all recommended")

| # | Decision | Taken |
|---|----------|-------|
| 1 | AZ-2092 AC-7 (2.1x cold, 2.3x warm, not 3x) | A: accept; amend AC-7 in the done spec and the README/perf notes (step 13). R2 (decimal range check on every packed integer) stays open as a Low |
| 2 | F25 / R1 / D4 / F26 / R4 | A: refuse at scheme construction → AZ-2305 |
| 3 | D2 all-null nested row under flags | B: counts as present, pack fails naming the first missing member → AZ-2306 |
| 4 | D8 AOT / IL2CPP | B now: one README sentence (step 13); a Unity IL2CPP run before a release that advertises Unity (recorded, not this loop) |
| 5 | E4 `Flags` as list/dict element | A: support, C# joins `listgroup`, `dictgroup`, `listflags` rings → AZ-2307 |
| 6 | E5 lone dictionary in a round | A: refuse like a lone collection, all packages that differ → AZ-2308 |
| 7 | E9 char / enum / object for numeric fields | A: keep the refusal (upgrade note); pinned in AZ-2309 AC-3 |
| 8 | E11 `u2` slots, `bits`, `packed` | A: strict rule → AZ-2309 |
| 9 | R3 AC-10 timing | done 2026-10-07 |
| 10 | AZ-2120 / AZ-2128 `when`, `times`, `repeat` as a `flags` member | A: all six packages write them (bytes `01 01 03 07 5a00` for the AZ-2120 shape) → wave 3 |

## Scope

Specs claimed (`loop: 18`): AZ-2120, AZ-2126, AZ-2128 (the `when`/`times`/`repeat` angle only), AZ-2135 (all other parts are done: Python by AZ-2230 in loop 16, C# in loop 17; the C++ follow-up is AZ-2304; it moves to `done/` when AZ-2304 ships), AZ-2194, and new AZ-2304 to AZ-2311. AZ-2068 (C++ AVR, optional stretch, stale loop 10 claim) stays out.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs exist in `todo/` (hopper hit; the eight new specs were written at intake) |
| decompose-feature | 9.5 | Decompose Feature | no | specs are 1 to 3 points |
| implement | 10 | Implement | yes | three waves, see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 19 handoff, no re-entry round (owner preference) |
| run-tests | 11 | Run Tests | yes | one total run: six package suites, hostile vectors, golden, `language-pair.sh` rings (now with C# in `listgroup`, `dictgroup`, `listflags`), embedded stages because `cpp/` changes |
| test-spec-sync | 12 | Test-Spec Sync | yes | the hostile vector set gains `eq_bool_false` and the `pack` stage |
| update-docs | 13 | Update Docs | yes | README upgrade notes (decisions 1 to 8, 10), AZ-2092 AC-7 amendment, D8 sentence, hostile README sections, stale docs listed in `record17.md` |
| security | 14 | Security Audit | yes | C# unpack of hostile bytes (F25 closed by AZ-2305), `pack` stage, construction checks in six packages |
| performance | 15 | Performance Test | no | no throughput AC is touched; AC-10 runs in step 11 |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag needs the owner's go with the exact commit |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | about 35 points across six packages |
| local-deploy | — | Local deploy + open site | yes | always at close; no site: package suites and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | always at close; one-paste script in `smoke18.md` |

## Implementation

### Files that change

One worker per package directory owns that directory (sources, tests): `typescript/`, `python/`, `rust/`, `java/`, `cpp/`, `csharp/`. The C# worker also owns the ring files for AZ-2307 in wave 1 (`.github/workflows/drivers/csharp/`, the handoff lines in `language-pair.sh`, `ring-wiring.test.sh`); no other wave-1 worker touches them. Parent-only: `_docs/**`, `README.md`, tracker, commits. Wave 2 owns `fixtures/hostile/**` and each package's hostile-vector loader test; wave 3 the package sources again.

### Order of work

1. **Wave 1** (parallel, cap 4 workers at a time: csharp, typescript, rust, java first; python, cpp when one finishes):
   - `csharp/`: AZ-2305, AZ-2306, AZ-2309, AZ-2310, AZ-2308 (C# part), AZ-2307, AZ-2126 C# (construction check; also the `when` source kinds: integer, bool only with `true`; reverse `FloatWhenTests` and `WrittenWhenKindsTests`).
   - `typescript/`, `python/`, `java/`: AZ-2126 construction check (no vector), AZ-2308 (probe first; refuse a lone dictionary for a `Dict` name in a round where the package broadcasts).
   - `rust/`: AZ-2126, AZ-2311, AZ-2308.
   - `cpp/`: AZ-2304, then AZ-2126.
2. **Wave 2** (one worker, after every package refuses `eq(bool, false)`): AZ-2126 hostile vector `eq_bool_false` and README section, then AZ-2194 (`pack` stage, five cases, `check-cases.sh` and its self-test, six loaders). Its numbers are stale (19 cases; stages `unpack`, `construct`, `limit`; AZ-2185 to AZ-2187 landed, so the long `times` list moves to `Run by`): the worker re-counts from the file.
3. **Wave 3** (six workers by directory, cap 4): AZ-2120 and the AZ-2128 angle: a `when`, `times` or `repeat` as a `flags` member or flag-bit field sets its bit when it writes a value, in all six packages.
4. Then: one total review, step 11 run, feature-assess, docs, security, retrospective, close, push, CI watch.

Each worker returns a status table and a `## Discovered during implementation` list; the parent checks `git diff --cached` (must stay empty) and the diff scope after each worker, writes `batch_NN_loop18_report.md`, and commits locally per wave.

### Proof

Per package: the package suite only (no Docker). C# on net10.0 and `-p:PackbinTarget=netstandard2.0`. Wire bytes of golden and route fixtures do not change. The differential rule of `LESSONS.md` for every conversion-path change (one hostile value outside the member's range). Shell-shaped host recipes are in `AGENT_GOTCHAS.md`.

### Risks

- AZ-2126 counts and `when` kinds: the decided concern widens the change per package; a package that already conforms only gets a test.
- AZ-2308 may touch up to five packages; each worker probes its own package first.
- Wave 3 changes bytes for the `when`/`times`/`repeat`-under-`flags` shape in five packages that agree today (`01 01 02 5a00`); recorded as an upgrade note.

### Divergence log

- Wave 1 ran as seven worker stages (C# split in two: A = AZ-2305, 2306, 2308, 2309, 2310; B = AZ-2126, AZ-2307 plus the ring files). AZ-2308 spread over five packages by direction (each worker probed its own package). AZ-2135 closed with AZ-2304 (its Python and C# parts were already done in loops 16 and 17). A hung `dotnet test` (missing `MSBUILDDISABLENODEREUSE=1`) cost the C# A stage about 15 minutes; the fix is in `AGENT_GOTCHAS.md`. Batch report: `_docs/03_implementation/batch_01_loop18_report.md`.
- Wave 2 (one worker, `fixtures/hostile/` and the six loaders) committed as `e4d76f9`; the `cpp/Makefile` dependency on `hostile_pack_cases.hpp` was fixed by the parent. Wave 3 ran in two stages (C# reference stage writing a hex-pinned table, then five workers in parallel) so six packages could not derive different readings. Batch reports 02 and 03.
