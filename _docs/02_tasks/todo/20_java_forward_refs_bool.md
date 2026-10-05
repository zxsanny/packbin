# Java rejects later/outer references and keeps `bool` inside flags

**Task**: 20_java_forward_refs_bool
**Name**: Java reference scope and bool placement
**Description**: Java schemes fail construction for references to later or outer fields and for a `bool` or empty group outside flags; a split-form bool bit unpacks as `true`.
**Complexity**: 2 points
**Dependencies**: 01_hostile_vectors (construct vectors), 08_java_unpack_state_per_call (both change the flag-bit unpack path in `Walker.java`), 05_java_hostile_unpack (same file; the repeat zero-progress rule)
**Component**: java
**Tracker**: pending
**Epic**: AZ-2069

## Problem

Each probe below was reproduced against a copy of the sources at `d108141` with JDK 21 unless marked "code reading".

### Defect 1 — `when` naming a later field silently drops data
- `java/src/main/java/packbin/SchemeOrder.java:10-17` walks the whole list, then `resolve(fields, scope)` (`:16`) checks references against a scope that holds every id (`:85-124`). A later id therefore passes.
- Probe: `when(0, eq(1, 1), u8(0, a))`, `u8(1, b)` on a `Map` scheme: constructs. Pack of `{a: 5, b: 1}` → **`01 01`**: `a` is silently dropped, because `conditionHolds` reads the per-call `seen` map (`Walker.java:408-414`), where `b` is not yet present.
- C# packs `01 05 01` and then cannot unpack it (task 18). C++ rejects at construction (`cpp/include/packbin/order.hpp:94-166`). README: "The tested field must already have been read".

### Defect 2 — borrowed count naming a later field
- Probe: `sized(0, p, countId 1)`, `u8(1, n)`: constructs. Pack of `{p: [01], n: 1}` → **`IllegalStateException: 0: count 1 is missing`** (`VarFields.java:18-21`). The same holds for `bits`, `packed` and the count of `times` (`:98-101`, `:144-154`).

### Defect 3 — outer references from inside `repeat`/`times`
- `walk` puts repeat/times children into the parent scope (`SchemeOrder.java:21-26`). Java resolves `when` at run time through the shared `seen` map, so an outer reference inside a repeat **does** match today. C++ (and, after task 18, C#) reject that shape. This task applies the C++ rule (C04): a reference must name an earlier field **in the same scope**. Repeat and times bodies, list/dict elements and nested rows are their own scopes.

### Defect 4 — `bool` outside flags does not round-trip
- `Packbin.boolField` (`Packbin.java:53-55`) can be used anywhere. As a top-level field, pack only records it in `seen` and writes nothing (`Walker.java:85`). Unpack returns `null` for it (`:129`), so nothing is stored.
- Probe: `boolField(0, on)`, `u8(1, n)`, row `{on: true, n: 7}` → `01 07`; unpack → `on = null`. **`true` is lost.**
- As a `repeat` body it reads 0 bytes, which causes the hang in task 05.

### Defect 5 — split-form bool bit loses `true`
- `fb.bit(boolField(0, on))` on a `flagByte()`: pack `{on: true}` → `01 01` (bit set, correct). Unpack → **`on = null`**.
- `unpackFlagBit` (`Walker.java:275-286`) calls `unpackField(inner)`, which returns `null` for `BOOL` without storing. Only the combined `flags(...)` path stores `true` (`:253-255`).

### Defect 6 — empty group outside flags
- `Packbin.group(0)` with no children constructs anywhere (probe: top level → constructs), and pack/unpack do nothing with it.
- User decision: an empty group is allowed only inside flags.

### Defect 7 — `repeat` with a `when`/`flags`/`group` child throws on pack (needed by AC-4)
- `Walker.java:173-189` `packRepeat` computes the round count from `child.get.get(row)` for **every** child. `when`, `flags` and continuing `group` have no getter.
- Probe: `repeat(0, flags(0, u8(0, a)))`, `{a: [1, 2]}` → **`NullPointerException`**. A `when` child fails the same way.
- The valid sibling-reference shape in AC-4 cannot be packed until this is fixed, so it belongs here. The count comes from value-bearing leaves, including those nested under flags, when and groups in the body.

Java's bit rule itself already matches the decision: `boolOn` = `Boolean.TRUE.equals(value)` (`Walker.java:22-24`). Probe: `flags(0, boolField b)`, `{b: false}` → `01 00`.

## Outcome

User decision 2026-10-05, verbatim: **"The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` / a flag byte — anywhere else is a scheme construction error."**

- A `when` condition id or borrowed count id must name a value field that comes earlier in the same scope. Otherwise `new Scheme<>(…)` throws `IllegalArgumentException` naming both ids.
- `boolField` or an empty `group` that is not a direct bit of `flags(...)` / `flagByte().bit(...)` fails construction with `IllegalArgumentException`.
- A set bool bit unpacks as `Boolean.TRUE` in both the combined and the split form. A clear bit stores nothing (the row keeps `null` / its default).

## Scope

### Included
- `SchemeOrder`: resolve references while walking; scope boundaries; bool/empty-group placement.
- `Walker`: split-form bool unpack; repeat round count from value-bearing leaves (Defect 7).

### Excluded
- Per-call flag state (task 08).
- Nested-row `seen` scoping at run time and the typed child factory (task 32).
- The 8-bit cap (already enforced, `Field.java:329`).
- C# (tasks 10, 18).

## Acceptance Criteria

**AC-1: Later `when` reference rejected**
Given `when(0, eq(1, 1), u8(0, a))`, `u8(1, b)`
When the scheme is built
Then `IllegalArgumentException` names condition id 1; 0 schemes; 0 bytes.

**AC-2: Later count reference rejected**
Given `sized(0, p, 1)`, `u8(1, n)`, and the `bits`, `packed`, `times` variants
When built
Then `IllegalArgumentException`.

**AC-3: Outer reference inside repeat/times rejected**
Given `u8(0, p)`, `repeat(1, u8(1, x), when(2, eq(0, 1), u8(2, y)))`, and the same inside `times`
When built
Then `IllegalArgumentException`.

**AC-4: Valid references still work**
Given the route scheme (`PackbinFieldsTest.java:369-383`), `FieldIdBindingTest.MARKER` (`when(4, eq(3, 1), …)`), and a `when` inside a repeat naming an earlier sibling of the same round
When built and used
Then the route hex `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` and the marker hex `2001000065cd1d00a3e111010000000000` round-trip.

**AC-5: bool outside flags rejected**
Given `boolField` at top level, in `when`, `repeat`, `times`, a list/dict element or a nested `group`
When built
Then `IllegalArgumentException`.

**AC-6: Empty group outside flags rejected**
Given `Packbin.group(0)` with no children outside a flags bit
When built
Then `IllegalArgumentException`.

**AC-7: Split-form bool unpacks true**
Given `fb = flagByte()`, `fb.bit(boolField(0, on))`
When `{on: true}` is packed and unpacked
Then the bytes are `01 01` and `on == Boolean.TRUE`; for `{on: false}` the bytes are `01 00` and `on` stays `null`.

**AC-8: Bit rule unchanged**
Given `flags(0, boolField b)`
When `{b: false}`, `{}` and `{b: true}` are packed
Then `0100`, `0100`, `0101`, matching C# after task 10.

## Non-Functional Requirements

**Compatibility**
- No wire change. Only schemes that could not round-trip stop constructing. Android API 26 APIs only.

## Unit Tests

AC-1, AC-2, AC-3, AC-5, AC-6, AC-7 must fail first. Use the runner's `expectThrows` helper with a non-empty failure path.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | probe `when(0, eq(1,1), u8 a)`, `u8 b` | throws at construction; today packs `0101` |
| AC-2 | probe `sized(0,p,1)`, `u8(1,n)`; `bits`/`packed`/`times` variants | throws at construction |
| AC-3 | outer `p` referenced inside `repeat`; inside `times` | throws |
| AC-4 | `repeat(0, u8(0,k), when(1, eq(0,1), u8(1,v)))`, `{k:[1,2], v:[9]}` | constructs; bytes `01 01 09 02`; round-trip |
| AC-4 | `PackbinFieldsTest.borrowedCount`, `FieldIdBindingTest` | pass |
| AC-5 | probe `boolField(0,on)`, `u8(1,n)` | throws; today `0107` and `on` lost |
| AC-6 | `Maps.scheme(1, Packbin.group(0))` | throws; today constructs |
| AC-7 | split-form probe `{on: true}` | `0101`, `on == TRUE`; today `null` |
| AC-8 | `{b:false}`, `{}`, `{b:true}` | `0100`, `0100`, `0101` |
| AC-4 | probe `repeat(0, flags(0, u8(0,a)))`, `{a:[1,2]}` | `01 01 01 01 02`; today `NullPointerException` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `fixtures/hostile/` construct vector `when_names_later_field` | Java suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-2 | `fixtures/hostile/` construct vector `count_names_later_field` | Java suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-3 | `fixtures/hostile/` construct vector `when_names_outer_field_in_repeat` | Java suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-5 | `fixtures/hostile/` construct vector `bool_outside_flags` | Java suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-6 | `fixtures/hostile/` construct vector `empty_group_outside_flags` | Java suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-8 | language-pair vector "bool false in flags" (tasks 10/11/14) | Java ↔ every package | `0100`, value false everywhere | AC-3 (project) |
| AC-4 | `fixtures/golden.hex`, route hex in `language-pair.sh` | Java pack/unpack | 0 mismatched bytes | AC-1/AC-2 |

## Constraints

- ADR-001: Java keeps its own checker; mirror the C++ rule (`order.hpp`) without sharing code.
- Id numbering unchanged (field-order AC-2/AC-3). Only reference lookup is scoped.
- No public API change.

## Risks & Mitigation

**Risk 1: Java schemes that used an outer reference inside `repeat` stop constructing**
- *Risk*: unlike C#, Java evaluated these consistently, so a caller may rely on them.
- *Mitigation*: other packages (C++, after tasks 06/18 Rust/C#) do not support them, so such packets were never portable. The error message names the rule.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rejecting outer references inside `repeat`/`times` removes a shape Java supported (C04: "the C++ rule in every package"). | user decision C04 | accepted-risk | Medium |
| Java's empty `group(anchor)` has no accessor, so even inside flags it can never set its bit (`Walker.groupOn`, `:37-47`). TS/Python/C# empty groups carry a presence member. Adding one is a public API change, out of scope here. | user / C15-style API review | open | Low |
