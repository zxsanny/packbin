---
loop: 118
branch: dev
---

# C#: set the bit of a `flags` that is a direct member of a `flags`; probe all nine packages

**Task**: AZ-4251_csharp_flags_in_flags_presence
**Name**: C#: set the bit of a `flags` that is a direct member of a `flags`; probe all nine packages
**Description**: C# drops the value of an inner `flags` with no error; make its presence bit follow its members as TypeScript does, pin it with tests, and probe the same scheme in all nine packages.
**Complexity**: 3 points
**Dependencies**: none
**Component**: `csharp/Walker.Presence.cs`, `csharp/tests/`; `scripts/probes/flags-in-flags/` (new); `_docs/06_metrics/` (findings)
**Tracker**: AZ-4251
**Epic**: AZ-4133

Queue item `csharp-flags-in-flags-presence` (found in loop 113, code review of AZ-4212), picked by loop 118. Problem: `_docs/02_task_plans/csharp-flags-in-flags-presence/problem.md`; scenarios and expected bytes beside it.

## Problem

`Flags(0, Flags(0, X), Bool)` with `X = 9` and the bool true packs `0102` in C# (typed and dictionary form): the inner `flags` writes nothing and its value is dropped with no error. TypeScript and Java pack `01030109`. The C# rule that decides whether a flag bit is on has no case for a `flags`, so an inner `flags` is never seen as holding a value. A value that is given must be written or refused, never dropped.

## Shapes

Scheme `S`, type 1: `flags(flags(u8 x), bool b)`. Field ids follow each package's own numbering rule.

| shape | values | TypeScript packs | read-back |
|-------|--------|------------------|-----------|
| `both` | `x = 9`, `b = true` | `01030109` | equal |
| `x-only` | `x = 9` | `01010109` | equal |
| `b-only` | `b = true` | `0102` | equal |
| `none` | nothing | `0100` | equal |

## Acceptance Criteria

**AC-1: C# writes the inner value**
Given scheme `S` in C# (typed form and dictionary form)
When it packs `both`
Then the packet is `01030109` and the typed unpack returns `x = 9`, `b = true`.

**AC-2: Every combination equals TypeScript**
Given scheme `S` in C#
When it packs `x-only`, `b-only` and `none`
Then the packets are `01010109`, `0102`, `0100` and each reads back to the values given.

**AC-3: Deeper nesting**
Given `flags(flags(flags(u8 x)))` in C#
When it packs `x = 9`
Then the packet is the TypeScript packet for the same scheme (`01010109` with one more `01`: `0101010109`) and reads back.

**AC-4: Nine-package probe**
Given `scripts/probes/flags-in-flags/run.sh`
When it runs with no argument on this Mac
Then each of TypeScript, C#, Python, Rust, Java, C++, Go, Swift and Dart prints one tab-separated line per shape (`package`, `shape`, `build`, `pack`, `unpack`, the format of `scripts/probes/repeat-followed-by-field/README.md`), nothing is written into the checkout, and the run exits 0.

**AC-5: Findings**
Given the probe output
When `_docs/06_metrics/flags-in-flags-probe_2026-11-13.md` is written
Then it has one row per package and shape marked same-as-TypeScript, different bytes, refused, raw exception or n/a; a package other than C# that differs becomes one decision row in `_docs/OPERATOR_TODO.md` (no fix in this loop).

**AC-6: Suite**
Given the change
When the whole C# suite runs on `net10.0` and `netstandard2.0` (`env MSBUILDDISABLENODEREUSE=1`)
Then 0 tests fail.

## Tests

| AC | test | kind |
|----|------|------|
| AC-1, AC-2 | `csharp/tests/FlagsInFlagsTests.cs`: the four shapes, typed pack + unpack, dictionary pack | unit (new) |
| AC-3 | same file, three levels | unit (new) |
| AC-4, AC-5 | `scripts/probes/flags-in-flags/run.sh` run at loop close; the findings file | probe |
| AC-6 | step 11 `scripts/loop-tests.sh` (C# stages) | suite |

## Non-Functional Requirements

- The probe runs in about a minute on the project's Mac (loop 112's nine-package probe took 31 to 43 s).
- `bash -n` and `shellcheck` clean (the `scaffold` stage checks `scripts/`).

## Constraints

- No package other than C# changes in this loop.
- A packet C# wrote before this change was already lossy; README upgrade notes only if a package other than C# changes bytes (none in this loop).
- Inherited: `_docs/00_problem/acceptance_criteria.md` cross-package byte equality.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A sibling package may also drop or refuse the inner value; the probe finds it and the fix waits for one owner decision for the class | agent | open | Low |
