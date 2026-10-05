# Refuse `eq` on a bool or empty-group id unless the value is `true`, all packages

**Task**: AZ-2126_eq_bool_true_only
**Name**: `eq` on a bool accepts only `true`
**Description**: A `when` whose `eq(...)` names a `bool` or an empty-group mark fails scheme construction unless the compared value is `true`, in every package.
**Complexity**: 3 points
**Dependencies**: AZ-2079, AZ-2080, AZ-2082, AZ-2083, AZ-2089 (the true-only bool rule)
**Component**: csharp, typescript, python, rust, java, cpp
**Tracker**: AZ-2126
**Epic**: AZ-2069

## Problem

After the true-only rule (loop 12), a `false` bool leaves its bit clear and is absent on the wire. A `when(eq(boolId, false))` can therefore never match on unpack, but the packages disagree on pack. Found by the loop 12 reviewers (C# F3, TypeScript/Python F1) and the TypeScript worker:

| Package | Scheme | Row | Pack | Own unpack |
|---------|--------|-----|------|------------|
| TypeScript | `flags(0,[bool(0,on)]), when(1, eq(0,false), [u8(1,v)])` | `{on:false, v:5}` | `010005` | `{ok:false, needed:0, left:1}` |
| C# | `Flags(0, Bool S), When(1, Eq(0,false), U8 W)` | `S=false, W=7` | `010007` | `TrailingBytes` |
| Python | same shape | `{on: False, v: 5}` | `0100` | ok, `v` absent |

Same row, different bytes (project AC-3), and two packages write packets they cannot read.

## User decision (2026-10-05)

`eq` on a bool or empty-group id accepts only `true`. Any other value is a scheme construction error in every package.

## Outcome

- Building a scheme with `eq(boolId, v)` where `v` is not `true` fails with the package's construction error, naming the `when` and the field.
- `eq(boolId, true)` keeps working and round-trips in every package.

## Scope

### Included
- The construction check in C#, TypeScript, Python, Rust, Java and C++.
- A hostile construct vector `eq_bool_false` in `fixtures/hostile/cases.txt` and its README section.

### Excluded
- Error kind and label (C15).

## Acceptance Criteria

**AC-1: `eq(bool, false)` is a scheme error**
Given `flags(0, bool(0, on))`, `when(1, eq(0, false), u8(1, v))`
When the scheme is built
Then construction fails naming the `when` and field 0, in every package

**AC-2: `eq(bool, true)` round-trips**
Given the same scheme with `eq(0, true)` and `{on: true, v: 5}`
When packed and unpacked
Then every package packs `010105` and unpacks `{on: true, v: 5}`

**AC-3: hostile vector**
Given the construct vector `eq_bool_false`
When each package builds the scheme it describes
Then `scheme_error`

## Constraints

- ADR-001: each package implements the check itself.
- Files stay at or under 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from loop 12 review findings; refine before the loop that takes it | coordinator | open | Low |
| Loop 12 assessment G3: also pin that a non-`true` value (`1`, `"yes"`) clears the bit — done for TS/C#/Java/Python in AZ-2129..AZ-2132 | coordinator | resolved | Low |
| A count naming a `bool` builds in Java and C++ (C++ `read_int` reads it as 0/1) but Java pack/unpack fail, TS refuses at pack, and Python packs and round-trips it when the bool is true (`010161`) but fails when it is false or absent. Decide here: refuse a bool count everywhere, or read it as 0/1 everywhere | coordinator | open | Low |
