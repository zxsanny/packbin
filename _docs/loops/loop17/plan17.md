# Autodev Loop Plan — Loop 17

loop: 17
kind: product
confirmed: true
branch:
ship: false

Loop works on `dev` (no worktree: this chat is the launcher, as loops 11 to 16; the five old `loop/*` worktrees are merged and idle). Intake: `_docs/loops/loop17/handoff17.md`. Owner answers 2026-10-07: the C# multi-target work was committed by the agent at the owner's request (`68ca4f8`, CI-parity PASS: net10.0 424, netstandard2.0 424, `publish-gate.test.sh` exit 0); the hopper comes before the Go package (AZ-2222); "continue with C#" means this loop is the **C# stream only**; AZ-2120 is held (decision below). Owner preference (memory `one-total-review-and-test`): workers run only their own package suite, no per-batch review and no per-batch Docker run, one total review and one step-11 run at the end, no chained feature-assess rounds (open angles go to the next handoff).

## Scope

In (all in `csharp/`; wave C1 then wave C2 of the handoff, 25 points counting only the open C# part of each spec):

| Batch | Spec | Open part | Points |
|-------|------|-----------|--------|
| 1 | AZ-2092 C# typed binding per scope | all | 5 |
| 1 | AZ-2093 C# honest AC-10 test | all (needs 2092) | 1 |
| 1 | AZ-2135 split bits by field order | C# (G4) | 2 |
| 1 | AZ-2128 flag group presence parity | C# part | 1 |
| 2 | AZ-2180 C# scheme clones its flag-bit groups | all | 2 |
| 2 | AZ-2181 C# count source is an integer field | all (owner decision 2026-10-06: integer only; count errors keep one exception type, see Decisions) | 2 |
| 2 | AZ-2182 C# lone value in a round | all (owner decision 2026-10-06: option A) | 2 |
| 2 | AZ-2119 C# group as list or dict element | all | 3 |
| 2 | AZ-2191 C# strict numeric pack for dictionary rows | all (`u2` slots and `bits`/`packed` items stay out, per the spec) | 1 |
| 2 | AZ-2114 hostile session tests | C# | 1 |
| 2 | AZ-2115 split-form reference bytes | C# | 1 |
| 2 | AZ-2121 flag-scope container tests | C# | 1 |

Held (stay in `todo/`): **AZ-2120** (owner decision 2026-10-07: hold; it needs all six packages to give the same bytes, goes with the `when`/`times`/`repeat` under `flags` decision to a loop that also touches the other five); **AZ-2126** (six packages and the `eq_bool_false` hostile vector), **AZ-2194** (all six vector loaders), **AZ-2068** (C++ AVR, optional), the C++ flag-scope parity spec to write, and the non-C# parts of every cross-package spec. A cross-package spec whose C# part ships stays in `todo/` with its `## Loop 16 progress` table updated (precedent: AZ-2134); its Jira ticket stays In Progress. A spec with nothing left after C# moves to `done/`.

## Foreign work in the tree

None. The owner's multi-target work is committed (`68ca4f8`). The guard of loop 16 is retired.

## Decisions taken as the proposed default (owner 2026-10-06: "take all recommendations")

- AZ-2181 Low row (count errors: `InvalidOperationException` vs `ArgumentException`): count errors become `ArgumentException` like every other pack failure; the upgrade note states it.
- AZ-2182: option A; the Rust map `times` follow-up (a lone scalar goes to round 0 only) is recorded in the batch report discovery table and the next handoff, not implemented here (non-C#).
- AZ-2092 Flagged concerns (element two-mode binding; typed `repeat`/`times` over a collection of rows): the spec's Excluded list stands (typed `repeat`/`times` keeps today's rule); the two-mode element rule gets a README paragraph in step 13.
- AZ-2191: `u2` slots and `bits`/`packed` item rounding stay out (spec text); recorded as a follow-up.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs exist in `todo/` (hopper hit) |
| decompose-feature | 9.5 | Decompose Feature | no | specs are 1 to 5 points |
| implement | 10 | Implement | yes | two serial C# batches (one worker each, same directory), see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | run once, read-only; EXTEND / CLARIFY rows are recorded in the next handoff, no re-entry round (owner preference) |
| run-tests | 11 | Run Tests | yes | one total run: C# on both targets, the other five packages unchanged but run by the ring, hostile vectors, golden, `language-pair.sh` ring |
| test-spec-sync | 12 | Test-Spec Sync | no | project ACs and scenarios unchanged; no hostile vector is added |
| update-docs | 13 | Update Docs | yes | README C# example and upgrade notes (typed binding, count errors, lone value in a round, bit order), `components/01_csharp_package/description.md` line 92 is stale, README C++ bullet (handoff suggestion), module docs of the walker split |
| security | 14 | Security Audit | yes | C# unpack of untrusted bytes and the typed walker change; re-verify carried F17 (typed `Unpack` throws on a round) |
| performance | 15 | Performance Test | yes | AZ-2092 AC-7 names throughput; the Release benchmark and the AC-10 test are run once here |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag is a separate owner go with the exact commit |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | about 25 points, a core-path rewrite |
| local-deploy | — | Local deploy + open site | yes | always at close; no site: the package suites and the gate tests are the local run |
| smoke | — | Smoke acceptance | yes | always at close; one-paste script in `smoke17.md` |

Only rows with `include: yes` are executed (plus close steps).

## Implementation

Optional. Created or patched when a batch diverges (`protocols/plan-diff-sync.md`).

### Files that change

One worker at a time owns `csharp/` (sources and `csharp/tests/`). Parent-only: `_docs/**`, `README.md`, tracker, commits, the language-pair driver `.github/workflows/drivers/csharp/` (touch only if AZ-2092 AC-2 needs the typed case and the CI owner agrees: the spec says "if the CI owner agrees" — the owner is the same person; add the typed case only if the worker proves a gap).

### Order of work

1. Batch 1 (9 points): AZ-2092, AZ-2093, AZ-2135 C#, AZ-2128 C#. `Walker.Counted.cs` is 455 lines and `Walker.cs` 396: split typed binding from dictionary binding by responsibility; every file stays at or under 500 lines.
2. Batch 2 (13 points, after batch 1 is committed): AZ-2180, AZ-2181, AZ-2182, AZ-2119, AZ-2191, then the test-only parts AZ-2114, AZ-2115, AZ-2121.
3. Each batch: worker runs `dotnet test csharp` (net10.0) and `dotnet test csharp -p:PackbinTarget=netstandard2.0` (424 tests at the start); wire bytes of every existing test and `fixtures/golden.hex` do not change; the differential rule from `LESSONS.md`: unpack random bytes and repack against an export of `HEAD`.
4. Parent: tracker In Progress before, local commit after (CI-parity gate: the same two `dotnet test` runs), batch report with `## Discovered during implementation`, dependency table and spec progress tables, tracker In Testing with read-back.

### Proof

Wire bytes unchanged for every existing test; AC tests of each spec fail first, then pass; the README C# example packs the README hex and unpacks back; typed position round trip at least 3x faster (target 300 ms Release for 100 000).

### Risks

AZ-2092 rewrites the core typed path (Risk 1: pin current bytes first by running every dictionary test also through typed rows). AZ-2181 reverses C# AZ-2088 AC-6, so existing hostile tests are rewritten. Batch 2 changes error kinds in two places (count errors, strict numeric pack): list them in the README upgrade notes.

## Assessment rounds

Optional. Appended by `protocols/feature-reentry.md`.
