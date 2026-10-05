# C# rejects references to later or outer fields at construction

**Task**: AZ-2087_csharp_forward_refs
**Name**: C# reference scope check
**Description**: A `when` condition or a borrowed count must name an earlier field in the same scope; anything else fails `Scheme<T>` construction.
**Complexity**: 5 points (2 for the reference check; 3 for the round slicing the owner added in loop 13, see Flagged concerns)
**Dependencies**: AZ-2070_hostile_vectors (construct vectors), AZ-2079_csharp_bool_rule_flag_limit (both add construction checks to `SchemeOrder` in `csharp/Packbin.cs`)
**Component**: csharp
**Tracker**: AZ-2087
**Epic**: AZ-2069

## Problem

`SchemeOrder` (`csharp/Packbin.cs:183-310`) first walks the whole field list and collects every id into one scope (`Validate`, `:185-192`). Only afterwards does it resolve references (`Resolve(fields, scope)` at `:191`; `ResolveField`, `:268-309`). A reference to an id that comes **later** in the list therefore resolves. `repeat` and `times` bodies are walked into the parent scope (`:198-205`), so a reference inside a body may name a field **outside** it. The README says "The tested field must already have been read" (`README.md:790`). C++ enforces exactly that (`cpp/include/packbin/order.hpp:94-166`: `find_ref` searches only before the referring field, and repeat/times/list/dict open their own scope).

### Defect 1 — `when` naming a later field: C# cannot read its own bytes
- Probe (copy of sources at `d108141`): `new Scheme<FwdRow>(1, Field.When(0, Condition.Eq(1, (byte)1), Field.U8<FwdRow>(0, x => x.A)), Field.U8<FwdRow>(1, x => x.B))` with `FwdRow { byte? A; byte B; }`.
  - Construction succeeds.
  - Pack `{ A = 5, B = 1 }` → `01 05 01`: the pack-side condition sees `B` because all values are in the map (`Walker.cs:436-441`).
  - Unpack of those bytes → **`TrailingBytes(left = 1)`**: `B` has not been read when the condition runs, so the group is skipped.
- Java: the same scheme constructs, and pack **silently drops** `A` (`01 01`) (task 20).

### Defect 2 — borrowed count naming a later field
- `Field.Sized<R>(0, x => x.P, countId: 1)` followed by `Field.U8<R>(1, x => x.N)` constructs. Pack reads `N` from the map (`Walker.Counted.cs:52-60`) and succeeds. Unpack hits `InvalidOperationException: P: count 'N' is missing` (`Walker.Counted.cs:69-70`). This is from reading the code. Java's same probe throws `IllegalStateException` already at pack.
- Applies to `Sized`, `Bits`, `Packed` and the count of `Times` (`Packbin.cs:279-292`).

### Defect 3 — reference from inside `repeat`/`times` to an outer field never matches
- `U8 P` (id 0), `Repeat(1, U8 X (1), When(2, Eq(0, (byte)1), U8 Y (2)))`. Pack builds each round's value slice from the repeat's direct children only (`Walker.cs:223-244`), and unpack reads each round into a fresh dictionary (`:364`). The condition on outer `P` is therefore always false: `Y` is **silently never written**, whatever `P` is. Construction accepts it. This is from reading the code. C++ rejects it; Rust had the same hidden case (task 06).

## Outcome

- A `when` condition id and a borrowed count id must name a value field that comes **earlier in the same scope**. A scope is the top-level list; each `repeat` body, `times` body, `list`/`dict` element and nested row opens a new one. `flags`, `when` and continuing groups stay in their parent's scope.
- Anything else fails `new Scheme<T>(…)` with `ArgumentException` naming the referring id and the referenced id.
- All existing schemes and bytes keep working.
- Added by the owner in loop 13 (review F1 of the first C# review: AC-4's pack leg did not hold): in a `repeat` / `times` round, pack reads every value by round index, including values under `when`, `flags`, flag bits and continuing groups, and unpack returns one list entry per round (`null` for a skipped round). This is the C# part of AZ-2134 (owner decision U2: A).

## Scope

### Included
- Reference resolution while walking, in `SchemeOrder`, for `When.Pred.FieldId` and `CountId` of `Sized`, `Bits`, `Packed`, `Times`.
- Scope boundaries for repeat/times bodies, list/dict elements and nested rows.

### Excluded
- Moving resolved names off the shared `Field`/`Condition` objects (task 19).
- Java (task 20).
- Changing id numbering. Repeat/times children still continue the parent's ids (field-order AC-2); only **reference lookup** is scoped.

## Acceptance Criteria

**AC-1: Later `when` reference rejected**
Given `When(0, Eq(1, 1), U8 A(0))` followed by `U8 B(1)`
When the scheme is built
Then `ArgumentException` names condition id 1. Schemes built: 0.

**AC-2: Later count reference rejected**
Given `Sized(0, P, countId: 1)` followed by `U8 N(1)`, and the same for `Bits`, `Packed`, `Times`
When the scheme is built
Then `ArgumentException`.

**AC-3: Outer reference from inside repeat/times rejected**
Given `U8 P(0)`, `Repeat(1, U8 X(1), When(2, Eq(0, 1), U8 Y(2)))`, and the same shape inside `Times`
When the scheme is built
Then `ArgumentException`.

**AC-4: Earlier references still work**
Given the route scheme (`BorrowedCountTests.cs:36-49`: `Packed` count 5, `Times` count 5, `When(9, Eq(3, true), …)`), `FieldIdBindingTests.MarkerScheme` (`When(4, Eq(3, 1), …)`), and a `when` inside a repeat that names an earlier sibling in the same round
When built and used
Then construction succeeds and the route hex `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` round-trips.

**AC-5: Unknown id still rejected**
Given a reference to an id that does not exist anywhere
When built
Then `ArgumentException` (unchanged behavior).

## Non-Functional Requirements

**Compatibility**
- No wire change. Only schemes that could not round-trip (AC-1..AC-3) stop constructing.

## Unit Tests

AC-1, AC-2 and AC-3 must fail on the current code (they construct today).

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | probe `FwdRow` scheme | `ArgumentException` at construction |
| AC-2 | `Sized(0, P, 1)` + `U8 N(1)`; `Bits`, `Packed(2,…)`, `Times(0, 1, …)` variants | `ArgumentException` each |
| AC-3 | outer `P` referenced by a `When` inside `Repeat`; and inside `Times` | `ArgumentException` |
| AC-4 | `Repeat(0, U8 K(0), When(1, Eq(0, 1), U8 V(1)))` (sibling reference) | constructs; `{K:[1,2], V:[9]}` packs only the rounds where K == 1 and round-trips |
| AC-4 | existing `BorrowedCountTests`, `FieldIdBindingTests`, `LayoutTests.WhenGroupWidth` | pass |
| AC-5 | `When(1, Eq(7, 1), …)` with no id 7 | `ArgumentException` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `fixtures/hostile/` construct vector `when_names_later_field` | C# suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-2 | `fixtures/hostile/` construct vector `count_names_later_field` | C# suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-3 | `fixtures/hostile/` construct vector `when_names_outer_field_in_repeat` | C# suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-4 | route fixture hex, `language-pair.sh` | C# ↔ other languages | 0 mismatched bytes | AC-3 (project) |
| AC-4 | `fixtures/golden.hex` | pack/unpack | identical | AC-1/AC-2 |

## Constraints

- ADR-001: C# keeps its own checker; mirror the C++ rule, do not share code.
- Field-order rules stay: ids still number repeat/times children from the parent counter (scheme-field-order AC-2), and lists/dicts/nested groups still start at 0 (AC-3).
- `ArgumentException` stays the construction error type.

## Risks & Mitigation

**Risk 1: A caller scheme with an outer reference inside repeat stops constructing**
- *Risk*: such a scheme constructed before, but its group was never written.
- *Mitigation*: the error message says that the reference must name an earlier field of the same repeat/times body.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The sibling reference inside `repeat` (AC-4, first row) relies on the per-round value slice. Loop 13: the slice now descends through `when` / `flags` / flag bits / continuing groups, and a nested `when` has pack, unpack and repack tests. Re-check after task 23 changes binding. | task 23 | resolved | Low |
| C# and Java must apply the same scope rule as C++ (`order.hpp`). Java task 20 copies these ACs. | tasks 18/20 | open | Low |
| Loop 13 owner decision (2026-10-05, after the first review FAILed AC-4's pack leg): fix C# round slicing here, not in a follow-up. Round count for `repeat` = the longest list among every name the round holds (a superset of the old direct-child rule); `times` keeps its borrowed count. | owner | resolved | Medium |
| Aligned unpack pads one `null` per optional name per round, so unpack memory is about packet bytes × names in the round (337 MB heap for a 1 MB packet and a 36-name `when` body, against 57 MB before). Linear and bounded by the scheme; Java, Rust and C++ behave the same. README untrusted-input note, no cap. | owner decision U2 | accepted-risk | Medium |
| Not fixed here (review Lows, follow-ups): a lone `byte[]` / `List<int>` for a Bytes / Sized / Bits / Packed name under `when` / `flags` is read as a list of rounds (`InvalidCastException` on pack); values of a `repeat` / `times` nested inside a round are not packed from the outer round (Java and Rust refuse the scheme); a lone scalar goes to round 0 only (Java broadcasts it); a `when` that holds with its value absent packs a packet its own unpack rejects (AZ-2088 area); typed-row `Unpack` of any repeat/times row throws `InvalidCastException` (pre-existing). | coordinator | open | Low |
