---
loop: 111
branch: dev
---

# C#: element row Lows — array and IList members, row type checked at build, when and times tested

**Task**: AZ-4205_csharp_element_row_lows
**Name**: C#: element row Lows — array and IList members, row type checked at build, when and times tested
**Description**: Close the three review Lows of AZ-4199: the element-row form for every list and dict member type C# accepts, a build-time refusal for members declared for another row type (element rows and nested rows), and tests for `when` and `times` inside an element row.
**Complexity**: 3 points
**Dependencies**: AZ-4199
**Component**: csharp (`Field.cs`, `Fields.cs`, `SchemeOrder.cs`, tests), docs (README C# List section)
**Tracker**: AZ-4205
**Epic**: AZ-4133

Owner choice 2026-11-12 (loop 111, empty hopper): "AZ-4199 Lows in C#"; scope decision "accept all recommended". Problem, ACs, expected I/O and scenarios: `_docs/02_task_plans/csharp-element-row-lows/`.

## Problem

AZ-4199 (loop 109) let a C# `List` or `Dict` element be a row of required members with no flag byte. Its review (PASS_WITH_WARNINGS) left three Lows, none applied. A probe on HEAD `05bdc52` measured each:

1. The row form takes only a `List<E>` list member or a `Dictionary<string, E>` dict member. The other member types C# accepts for list and dict fields (`E[]`, `IList<E>`; `IDictionary<string, E>`) cannot use it, so such a row needs a flags element (1 byte more per element) or a different member type.
2. A member declared for another row type inside an element row builds, then `Pack` and `Unpack` throw a raw `InvalidCastException` (`Unable to cast object of type 'Mark' to type 'Other'`). A nested row (a `Group` without anchor) has the same hole. A top-level member is refused when the scheme is built (`'Z' is declared for row type Other, but this scheme is for Mark`). Such a scheme cannot pack or unpack any row today, so no working scheme depends on it.
3. `when` and `times` inside an element row had no test. They work and C# writes TypeScript's bytes (`010200010700`, `01020002050600`, measured in both).

## Outcome

- A C# scheme author uses the row form with any list or dict member type the package accepts for a typed element.
- A member declared for the wrong row type fails when the scheme is built, with a message naming it, never as an exception out of `Pack` or `Unpack`.
- `when` and `times` inside an element row are held to TypeScript's bytes by tests.

## Scope

### Included
- `Fields<T>.List` and the static `Field.List` take the members of an element row for an `E[]` and an `IList<E>` member; `Fields<T>.Dict` and `Field.Dict` for an `IDictionary<string, E>` member. Same bytes as the `List<E>` / `Dictionary<string, E>` form.
- The scheme build checks the declared row type of every member inside an element row (list and dict) and inside a nested row, with the rule top-level members already have (the declared type or a base type of it is accepted).
- Tests for AC-1 to AC-3b; README C# List section (AC-5).

### Excluded
- A `repeat` inside a list or dict element, or any field after a repeat: both pack bytes their own unpack refuses, in C# and TypeScript (`010200010502`; `01050609`). Owner decision 2026-11-12: its own cross-package task for a later loop, not changed here.
- Optional members in an element row (the flags element stays the form for that).
- A non-generic `IList` / `IDictionary` member for the row form (no element type to bind the row to).
- Other packages' code and fixtures.

## Acceptance Criteria

**AC-1: Array and IList members**
Given the AZ-4199 `Comment` rows in a `Comment[]` member, and in an `IList<Comment>` member
When the row form is written with `Fields<T>.List` and with the static `Field.List`, and 0, 1 and 3 rows are packed
Then the hex equals the `List<Comment>` form (`010000`, `One`, `Three` of `ElementRowTests`), and unpack gives an array (empty for 0, never null) / a list of equal rows; a null member is refused as the `List<E>` form refuses it.

**AC-1b: IDictionary member**
Given `{b: C2, a: C1}` in an `IDictionary<string, Comment>` member
When the row form is written with `Fields<T>.Dict` and with `Field.Dict` and packed
Then the hex equals `Map` of `ElementRowTests` and unpack gives 2 equal rows.

**AC-2: Wrong row type refused at build (element row)**
Given `Field.List<Marked, Mark>(x => x.Items, Field.U8<Other>(0, o => o.Id), Field.U8<Other>(1, o => o.Z))` (and the same for `Field.Dict`)
When the scheme is built
Then the `Scheme` constructor throws `ArgumentException` whose message names the member (`Z` or `Id`), its declared type (`Other`) and the row type (`Mark`); `Pack` and `Unpack` are never reached.

**AC-2b: Wrong row type refused at build (nested row); base type accepted**
Given `Field.Group<Nest, Mark?>(x => x.M, Field.U8<Other>(0, o => o.Z))`
When the scheme is built
Then the same refusal; and members declared for a base type of the nested or element row type build and round-trip.

**AC-3: `when` in an element row**
Given the element row `(u8 mode, when(mode == 1, u8 speed))` and items `{1, 7}`, `{0}`
When packed and unpacked
Then the hex is `010200010700` (TypeScript's) and the rows come back `{1, 7}`, `{0, 0}`.

**AC-3b: `times` in an element row**
Given the element row `(u8 c, times(1, c, u8 v))` and items `{2, [5, 6]}`, `{0, []}`
When packed and unpacked
Then the hex is `01020002050600` (TypeScript's) and the rows come back equal.

**AC-4: Nothing else moves**
Given the current fixtures, golden vectors and C# tests
When the whole C# suite runs on `net10.0` and `netstandard2.0`
Then 0 bytes differ, every existing test passes, and every README C# example still compiles (no call picks another overload).

**AC-5: Documented**
Given the README C# List section
When it is read
Then it names the member types the row form takes (`List<E>`, `E[]`, `IList<E>`; `Dictionary<string, E>`, `IDictionary<string, E>`) and that a member declared for another row type is refused when the scheme is built.

## Non-Functional Requirements

**Compatibility**
- Builds and passes on both targets (`netstandard2.0`, `net10.0`); existing public spellings unchanged.

**Performance**
- The check runs once at scheme build; pack and unpack paths unchanged (existing timing tests hold at their bounds).

## Contract

The public contract of the C# package is the README C# section and its tests (no `_docs/02_document/contracts/library` file covers the C# list API; AZ-4199 added none). New public overloads:
- `Fields<T>.List<TChild>(Expression<Func<T, TChild[]>>, Func<Fields<TChild>, Field[]>)`, `Fields<T>.List<TChild>(Expression<Func<T, IList<TChild>>>, Func<Fields<TChild>, Field[]>)`, `Fields<T>.Dict<TChild>(Expression<Func<T, IDictionary<string, TChild>>>, Func<Fields<TChild>, Field[]>)`
- `Field.List<T, TChild>(Expression<Func<T, TChild[]>>, params Field[])`, `Field.List<T, TChild>(Expression<Func<T, IList<TChild>>>, params Field[])`, `Field.Dict<T, TChild>(Expression<Func<T, IDictionary<string, TChild>>>, params Field[])`
- New refusal at scheme build: a member inside an element row or nested row declared for a type that is not the row type nor a base of it (`ArgumentException`).

Exercised project ACs: wire format unchanged (`_docs/00_problem/acceptance_criteria.md` baseline; every package reads every other's bytes). No new seams (single component).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `Comment[]` and `IList<Comment>` members, 0 / 1 / 3 rows, `Fields<T>` and static forms; null member | Same hex as the `List<Comment>` form; equal rows; empty array for 0; null refused as today |
| AC-1b | `IDictionary<string, Comment>` member, both forms | `Map` hex; 2 equal rows |
| AC-2 | Element row (list, dict) with members of `Other` | `ArgumentException` at build naming member, `Other`, `Mark` |
| AC-2b | Nested row with members of `Other`; element and nested rows with members of a base type | Refused at build; base type builds and round-trips |
| AC-3 | `when` in an element row | `010200010700`; `{1, 7}`, `{0, 0}` |
| AC-3b | `times` in an element row | `01020002050600`; equal rows |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | Whole C# suite on both targets | `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp` (with a console logger) | 0 failures; 0 byte differences in fixture and golden suites | Compatibility, Performance |
| AC-5 | README C# List section | Read; README C# example tests, if any, run | Member types and the build refusal named | — |

## Constraints

- No change to the bytes or behavior of any scheme that builds and packs today.
- The row-type rule is the existing top-level rule (`SchemeOrder.RequireRow`), applied to the rows the members belong to; no second rule.

## Risks & Mitigation

**Risk 1: An overload changes which overload an existing call picks, or makes it ambiguous (CS0121)**
- *Mitigation*: AC-4 builds and runs every C# test and README example on both targets.

**Risk 2: A scheme that builds today is refused**
- *Mitigation*: such a scheme cannot pack or unpack any typed row today (probe: a null row is refused as "has no value", a non-null one throws `InvalidCastException` in `Pack` and `Unpack`). A scheme used only with map rows (dictionaries, values found by member name) could work and is now refused, as a top-level member of another row type already is (review Low, loop 111; owner accepted nested rows in scope).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| New overloads beside `List<E>` may change overload resolution of existing calls | build every test and README example on both targets (AC-4) | open | Medium |
| The nested-row check refuses a scheme that builds today | owner accepted nested rows in scope (2026-11-12); no such scheme can pack or unpack a row | accepted-risk | Low |
| The repeat class stays unfixed in this loop | owner decision 2026-11-12: own cross-package task | accepted-risk | Medium |
