---
loop: 25
branch: dev
---

# Probe the other four for an anchored group with no takers (D1)

**Task**: AZ-2456_anchor_group_no_takers_probe
**Name**: Probe the other four for an anchored group with no takers
**Description**: D1 A: a `Flags(0, Group(0,"mark")), U8(0,"n")` row packs as TypeScript in Go. Probe the four packages that are not pinned yet (Python, Rust, C#, Java; C++ already pins the row) and document the outcomes. No code change if a package already matches TypeScript; a bug ticket if it does not.
**Complexity**: 1 point
**Dependencies**: none
**Component**: all seven (probe only)
**Tracker**: AZ-2456
**Epic**:

## Problem

D1 (handoff 25, D-batch 2026-10-14) names a hostile row: a `Flags` with a `Group` whose anchor is the next field but that `Group` takes none of the members (`U8` sits beside, not inside). TypeScript packs it; Go does too (loop 24 pinned). The four packages between them (Python, Rust, C#, Java) have not been pinned. The owner chose A (keep the current cross-package behavior and document); the probe is read-only unless an outlier is found, in which case a bug is opened and left to the next loop.

Reference: `_docs/02_task_plans/round-parity-and-construction-checks/` (U-row table), `_docs/loops/loop24/assessment24.md` (D1).

## Outcome

- One probe row per package in `_docs/02_task_plans/round-parity-and-construction-checks/` (or the parity rows doc the project already uses) with the hex each package produced for the `Flags(0, Group(0,"mark")), U8(0,"n")` row with `{ n: 1 }` and `{}`.
- No code change in Python, Rust, C#, Java (if they already match TypeScript); a Bug ticket written to `_docs/02_tasks/todo/` for every outlier, with the hex and the owner's decision needed.
- No fix in this ticket: fixes are owner-approved and loop 26 or later.

## Scope

### Included

- Read-only probes (one short script or test per package that prints the bytes); the rows are documented in the project's parity doc.
- Owns (exclusive write): `_docs/02_task_plans/round-parity-and-construction-checks/` additions, and any `AZ-NNNN_<pkg>_anchor_group_no_takers_outlier.md` the probe opens.

### Excluded

- Any code change in a package. If an outlier is found, open a Bug ticket and stop; the fix is a separate ticket.
- The Go and C++ pin: already in place (loop 24 for Go, earlier for C++).

## Acceptance Criteria

**AC-1: Each of the four is probed**
Given the scheme `Flags(0, Group(0, "mark")), U8(0, "n")`
When each package's probe runs on `{ n: 1 }` and `{}`
Then the hex of each run is recorded in the parity doc; probed packages 4; packages skipped 0.

**AC-2: Outliers get a Bug ticket**
Given an outlier (its bytes differ from TypeScript's for a reason that is not already documented)
When the probe sees it
Then one `AZ-NNNN_<pkg>_anchor_group_no_takers_outlier.md` ticket is written with the hex, the TypeScript reference, and the owner's decision needed; count of outliers equals count of new tickets.

**AC-3: No code change in a passing package**
Given a package whose bytes already match TypeScript
When the probe runs
Then the package's source is untouched; `git diff <pkg>/` returns 0 lines.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | probe Python, Rust, C#, Java | 4 rows in the parity doc |
| AC-2 | probe Python, Rust, C#, Java | one Bug ticket per outlier |
| AC-3 | after the probe | no `<pkg>/` edits |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `Flags(0, Group(0,"mark")), U8(0,"n")` on `{ n: 1 }` and `{}` | pack, print hex | 4 rows recorded | |
