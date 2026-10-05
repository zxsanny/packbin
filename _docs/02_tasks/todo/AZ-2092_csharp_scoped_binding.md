# C# nested rows and list/dict elements bind per scope

**Task**: AZ-2092_csharp_scoped_binding
**Name**: C# typed binding per scope
**Description**: C# packs and unpacks typed rows through each field's own accessor, so nested rows and row-typed list/dict elements work; the README C# example runs.
**Complexity**: 5 points
**Dependencies**: AZ-2088_csharp_pack_fails_loudly (absence rules, declaring row type per field), AZ-2079_csharp_bool_rule_flag_limit, AZ-2076_csharp_unpack_state_per_call (walker state)
**Component**: csharp
**Tracker**: AZ-2092
**Epic**: AZ-2069

## Problem

The typed C# API (`Scheme<T>`, `Fields<T>`, `Pack(scheme, row)`, `Unpack(bytes, scheme.On(row => …))`) does not walk the row. `BinaryPacker.Pack` (`csharp/Packbin.cs:127-132`) flattens the row into one `Dictionary<string, object?>` keyed by member name (`ObjectValues.From`, `ObjectValues.cs:22-50`). Nested class members are merged into the **same** dictionary (`Collect`, `:37-50`). Unpack builds a flat dictionary and copies it back by member name with reflection (`ObjectValues.To/Apply`, `:30-73`; `ConvertValue`, `:99-119`). The accessor each field was declared with (`x => x.Member`) is reduced to its name (`MemberAccess`, `FieldAccess.cs:6-54`; its `Get`/`Set` delegates are built but never used). Probes were reproduced against a copy of the sources at `d108141`.

### Defect 1 — nested member names overwrite outer ones
- `new Scheme<OuterRow>(1, Field.U8<OuterRow>(0, x => x.Name), Field.Group((OuterRow x) => x.Inner, Field.U8<InnerRow>(0, i => i.Name)))`; row `{ Name = 1, Inner = { Name = 2 } }` → **`01 02 02`** (expected `01 01 02`): the outer value is replaced by the inner one, with no error. `SchemeOrder` cannot see this, because nested ids restart at 0.

### Defect 2 — the README C# example throws on pack and on unpack
- `README.md:157-200`: `f.List(x => x.Roles, r => r.Utf8(0, role => role.RoleName))` and `f.Dict(x => x.Access, e => e.List(a => a.Actions, n => n.Utf8(0, action => action.Action)))`, with `List<Role>` and `Dictionary<string, ActionList>`.
- Pack → **`ArgumentException: RoleName: expected string`**. `PackList` (`Walker.Counted.cs:255-269`) puts the `Role` object under the element name, and `PackUtf8` (`:222-232`) expects a string.
- Unpack of the README hex `0103006164610200040075736572050061646d696e020003006d61700200040072656164040065646974050073746f7265010005007772697465` → **`InvalidCastException: Invalid cast from 'System.String' to 'Role'`** (`ConvertValue`, `ObjectValues.cs:113-118`).
- Tests and the C# language-pair driver (`.github/workflows/drivers/csharp/Handoff.cs:43-49,119-122`) use only the dictionary path, so CI never ran the typed form.

### Defect 3 — a list of nested rows writes no element bytes
- `Field.List((ListRow x) => x.Items, Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.V)))`, `Items = [ { V = 3 } ]` → **`01 01 00`**: count 1, `V` lost, no error.

### Defect 4 — reflection on every call (performance)
- `ObjectValues.Members` (`:121-145`) calls `GetProperties`/`GetFields` and allocates delegates on every pack and unpack. Typed path: 100 000 position round trips take **719 ms Release / 933 ms Debug** on an M-series Mac, against **81 / 195 ms** for the dictionary path. Project AC-10 allows 1 s, and CI runs Debug on slower hosts. Task 24 makes the AC-10 test time this path.

Cross-language: Java walks the row through `Getter`/`Setter` per field (`Walker.java:134-139`), so names never clash (its own nested-row issues are task 32). TypeScript has the same name-clash defect (task 22). The README C# example is the documented counterpart of the Rust example on the same hex.

## Outcome

- Pack reads every value through the accessor its field was declared with, starting from the row object. A nested group reads its member object and walks its children on that object. A list/dict element of a row type walks the element field on each item.
- Unpack creates the row, nested row objects and list/dict element objects of their declared types, and sets members through the same accessors.
- The README C# example packs exactly the README hex and unpacks back to an equal `User`.
- Accessors are resolved once at construction. The typed position round trip is at least 3× faster than today (target ≤ 300 ms Release for 100 000 on the reference Mac).
- Wire bytes are unchanged for every existing test, the golden fixture and the language pairs.

## Scope

### Included
- A typed pack/unpack walk in `Walker*.cs` driven by per-field accessors (compiled or delegate-based, built once), replacing `ObjectValues` for typed rows.
- Nested groups (`Field.Group(accessor, …)` with a class member), lists and dicts with row-typed elements, nested lists/dicts (`Dictionary<string, ActionList>` → `List<ActionName>`).
- The existing primitive-element form (`Field.List((ListRow x) => x.Xs, Field.U16<U16El>(0, n => n.N))` with `ushort[] Xs`) keeps working.
- Collection creation on unpack for `List<E>`, `E[]`, `Dictionary<string, E>`.
- README C# example as an executable test (the exact snippet).

### Excluded
- The dictionary overload `Pack(scheme, IReadOnlyDictionary<…>)` and internal `Read`. They keep today's flat-name semantics, which tests and the language-pair driver rely on.
- Typed `repeat`/`times` binding to collections of rows. Today a typed `Times` field must be a scalar member, so a typed row cannot hold two rounds (see Flagged concerns).
- Error labels (C15). Removing public `Bound<T>` (C22).

## Acceptance Criteria

**AC-1: No name clash**
Given the Defect 1 scheme and `{ Name = 1, Inner = { Name = 2 } }`
When packed and unpacked
Then the bytes are `01 01 02` and the row round-trips with both values.

**AC-2: README example packs the README hex**
Given the README `User` scheme and row (`Username "ada"`, roles `user`, `admin`, access `map → read, edit`, `store → write`)
When `BinaryPacker.Pack(userScheme, row)` runs
Then the hex equals `0103006164610200040075736572050061646d696e020003006d61700200040072656164040065646974050073746f7265010005007772697465`.

**AC-3: README example unpacks**
Given that hex and the README's three handlers
When `BinaryPacker.Unpack` runs
Then it returns `null`, only the `User` handler runs, and the row equals the packed row: role order kept, dict keys `map`, `store` with their lists.

**AC-4: List of nested rows**
Given the Defect 3 scheme and `Items = [ {V=3}, {V=4} ]`
When packed and unpacked
Then `01 02 00 03 04`, and two `Item` objects come back.

**AC-5: Primitive element form unchanged**
Given `LayoutTests.CountedList`/`CountedDict` and `FieldIdBindingTests.Ac4` (`ushort[] Points` with an element row `PointEl`)
When run with typed rows as well as dictionaries
Then identical bytes, e.g. `01020001000200` and the F-AC-1 hex (103 bytes after the type byte).

**AC-6: Nested row under flags**
Given `ObjectBindingTests.Object_nested_group_and_short_packet` (`Session` under `Flags`)
When packed and unpacked
Then `01010700e8030000` and `Session = { Login 7, Ts 1000 }`. A `null` `Session` gives `0100` and comes back `null`. The short packet `01 01 07` is still `ShortPacket(field "Login", 2, 1)`.

**AC-7: Throughput**
Given the golden position row
When 100 000 typed `Pack` + `Unpack(handler)` round trips run in Release
Then elapsed ≤ 300 ms on the reference Mac and ≤ 1 s in the CI container (project AC-10).

**AC-8: Existing bytes unchanged**
Given all C# tests, `fixtures/golden.hex` and `language-pair.sh`
When run
Then all pass with 0 mismatched bytes.

## Non-Functional Requirements

**Performance**
- No reflection per call. Accessors are built once per scheme field.

**Compatibility**
- Public signatures of `Scheme<T>`, `Fields<T>`, `Field.*`, `BinaryPacker` and `PackSession` unchanged.

**Reliability**
- A nested or element type without a parameterless constructor fails at scheme construction, not at unpack.

## Unit Tests

AC-1, AC-2, AC-3, AC-4 must fail first.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `OuterRow/InnerRow` probe | `010102`; today `010202` |
| AC-2 | README snippet verbatim (`Readme_CSharpExample_Packs`) | README hex; today `ArgumentException` |
| AC-3 | README hex → `Unpack` with `userScheme`, `ping`, `note` handlers | `User` equal; today `InvalidCastException` |
| AC-4 | list of `Holder.Item` rows, two items | `01 02 00 03 04`; today one item gives `01 01 00` |
| AC-5 | existing list/dict tests, plus the same cases through typed rows | same hex both ways |
| AC-6 | existing `ObjectBindingTests` | pass |
| AC-7 | timing test (task 24 owns the AC-10 assertion; here a Release benchmark log) | ≤ 300 ms reference |
| — | nested type without a parameterless ctor | `ArgumentException` at construction |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | README hex (also produced by the Rust example) | C# typed pack → Rust unpack in `language-pair.sh` (add a typed C# case to `Handoff.cs` if the CI owner agrees) | 0 mismatched bytes | AC-3 (project) |
| AC-8 | `fixtures/golden.hex` | typed pack/unpack | identical | AC-10 |

## Constraints

- ADR-001: one walker per language, no shared code. Mirror Java's accessor-per-field idea, not its code.
- No wire change. The language-pair suite is the guard.
- Files ≤ 500 lines. `Walker.cs` is 455 lines: split by responsibility (e.g. typed binding vs. dictionary binding) rather than growing it.

## Risks & Mitigation

**Risk 1: Core path rewrite breaks a rarely tested kind**
- *Mitigation*: before the rewrite, run every existing dictionary-based test also through typed rows (AC-5) to pin current bytes.

**Risk 2: Two binding modes (typed vs dictionary) drift**
- *Mitigation*: the dictionary path stays the test/driver path. Add a parity test that packs the same data through both for every kind.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The element binding needs two modes: an item of the element field's row type is walked through its accessor, and any other item (primitive, string) is the element value itself (today's `U16El` form). This is a visible rule and should be documented in the README. | user | open | Medium |
| Typed `repeat`/`times` cannot hold more than one round in C# (a `Times` child must bind a scalar member; `List<byte>` does not compile against `Field.U8`). Rust got the decision "typed `times` binds a `Vec<E>` of element rows"; C# needs the same decision before it can be fixed. | user | open | Medium |
| README C# example output must equal the Rust example's bytes; if the README hex itself is wrong, fix the README, not the test. | docs owner | open | Low |
