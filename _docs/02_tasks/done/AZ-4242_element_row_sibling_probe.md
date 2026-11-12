---
loop: 116
branch: dev
---

# Probe the element-row class of AZ-4199 / AZ-4205 in Java, Go, Swift, Rust, Python and C++

**Task**: AZ-4242_element_row_sibling_probe
**Name**: Probe the element-row class of AZ-4199 / AZ-4205 in Java, Go, Swift, Rust, Python and C++
**Description**: Committed probes that show, per package, what a list or dict element row accepts, what it refuses and with which error, and whether its bytes equal TypeScript's; one findings table.
**Complexity**: 3 points
**Dependencies**: AZ-4199, AZ-4205 (done)
**Component**: `scripts/probes/element-row/` (new), `_docs/06_metrics/` (findings); no package source
**Tracker**: AZ-4242
**Epic**: AZ-4133

Queue item `element-row-sibling-probe` (loop 111 leftovers), picked by loop 116. Problem: `_docs/02_task_plans/element-row-sibling-probe/problem.md`.

## Problem

C# had three defects in the element-row form (a list or dict whose element is a row of required members, no flag byte per element): some collection member types could not use it, a member declared for another row type threw a raw cast exception out of pack and unpack, and `when` / `times` inside an element row were untested. Fixed in C# (AZ-4199, AZ-4205). The six other packages that were not checked may have the same class.

## Shapes

Type number 1. Members as AZ-4199: `Comment = (utf8 id, utf8 text, u32 authorId, utf8 author)`, ids 0 to 3; `c1 = {c1, hi, 7, ann}`, `c2 = {c2, ok, 258, bo}`, `c3 = {c3, yes, 1, cy}`. Expected hex is TypeScript's (pinned in `typescript/tests/list-of-nested-rows.test.ts` and the C# tests; the TypeScript probe re-measures it).

| shape | scheme | values | TypeScript |
|-------|--------|--------|------------|
| `list-0` | `list items` of element row `Comment` | `[]` | `010000` |
| `list-1` | same | `[c1]` | `010100` + c1 |
| `list-3` | same | `[c1, c2, c3]` | `010300` + c1 c2 c3 |
| `dict-2` | `dict map` of element row `Comment` | `{b: c2, a: c1}` | `010200` + `021061` c1 `021062` c2 |
| `coll-<type>` | `list-3` / `dict-2` with each other collection member type the package accepts for a list or dict field (for example an array, a read-only list, a tuple, an interface type) | as `list-3` / `dict-2` | the `list-3` / `dict-2` hex |
| `when` | element row `(u8 mode, when(mode == 1, u8 speed))` | `[{1, 7}, {0}]` | `010200010700`, reads back `{1, 7}`, `{0, 0}` (or `{0}` where an absent member stays absent) |
| `times` | element row `(u8 c, times(1, c, u8 v))` | `[{2, [5, 6]}, {0, []}]` | `01020002050600`, reads back equal |
| `other-row` | `list-3` scheme where members are declared for a row type other than the element's (typed APIs only) | `[c1]` | n/a in TypeScript (no row types); C# now refuses at build naming the member |
| `nested-other-row` | a nested row (group without anchor) whose member is declared for another row type | one row | as `other-row` |
| `null-member` | `list-1` with `c1.text` missing / null | `[c1']` | refused, naming the member |
| `null-item` | `list-3` scheme, a list `[c1, null]` | — | refused |

## Acceptance Criteria

**AC-1: One probe per package**
Given `scripts/probes/element-row/run.sh`
When it runs with no argument on this Mac
Then each of TypeScript, Java, Go, Swift, Rust (std and `nostd` where it can), Python and C++ prints one tab-separated line per shape it has (`package`, `shape`, `build`, `pack`, `unpack`, the output format of `scripts/probes/repeat-followed-by-field/README.md`), and the run exits 0.

**AC-2: Every shape answered**
Given a package and a shape of the table
When the package cannot write the shape
Then its line says `n/a: <why>` (for example "no typed rows", "does not compile: <message>"), never a missing line; a raw exception is printed as `threw: <type: message>`, distinct from the package's own refusal.

**AC-3: Findings compared with TypeScript**
Given the probe output
When the findings file `_docs/06_metrics/element-row-probe_2026-11-12.md` is written
Then it has one table row per package and shape with the outcome, and marks each line as same-as-TypeScript, different bytes, refused, raw exception, or n/a; the defects are listed as one class with a recommended decision.

**AC-4: Repeatable and clean**
Given two runs of the probe on the same checkout
When the outputs are compared
Then they are byte-identical, and `git status` shows no file written by the probe.

**AC-5: No package change**
Given the loop's diff
When it is read
Then no file under `typescript/`, `java/`, `go/`, `swift/`, `rust/`, `python/`, `cpp/`, `csharp/`, `dart/` changed.

## Non-Functional Requirements

- The whole probe runs in about a minute on the project's Mac (loop 112's took 31 to 43 s); Go runs in `golang:1.27` when `go` is not on `PATH`.
- `bash -n` and `shellcheck` clean (the `scaffold` stage of `scripts/loop-tests.sh` checks `scripts/`).

## Constraints

- Probe only (loop 112 practice): a fix follows the owner's decision for the class.
- Out of scope: C# (fixed) and Dart (pins the AZ-4199 bytes since loop 109).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A package's "collection member types" differ by language; the probe lists the ones its public API accepts for list/dict fields and says so in the README | agent | open | Low |
