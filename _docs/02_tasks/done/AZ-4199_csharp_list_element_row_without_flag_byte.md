---
loop: none
branch: dev
---

# C#: a list or dictionary element can be a row of required members with no flag byte

**Task**: AZ-4199_csharp_list_element_row_without_flag_byte
**Name**: C#: a list or dictionary element can be a row of required members with no flag byte
**Description**: The C# package can write a `List` or `Dict` whose element is a row of several members only inside a flags container; give it the plain nested row the TypeScript and Dart packages describe, so a list of rows costs no flag byte per element.
**Complexity**: 3 points
**Dependencies**: None (found by the Archangel task AR-967, 2026-11-11; nothing in Archangel waits for it)
**Component**: csharp (`Field.cs`, `Fields.cs`, `SchemeOrder.cs`), docs (README C# section), shared fixtures
**Tracker**: AZ-4199 (written from another repository: Archangel `AR-967`)
**Epic**: AZ-4133

Requested by the Archangel owner on 2026-11-11: any gap found in the C# or Dart package goes into this repository as a task, never worked around in the application.

## Problem

Archangel's marker frame carries a list of comments, each with four required members (`id` text, `text`, `authorId` u32, `author` text). Written with Packbin 0.5.0 C# the element can only be one of: a single field, a flags container (`Flags`), or a nested group that needs a wrapper property on the row. A nested row of four required members with no flag byte is not expressible without a wrapper class: `Field.cs` rejects an accessor onto the element row itself (`accessor must be a member access`) and `Fields.cs` has no `Group` overload over the element row. Archangel therefore wrote each comment as a one-member flags element with all four members set, which costs **one extra byte per comment** (a constant `0x0f`) and makes the layout differ from the plain nested row the Dart README describes (`nested(name, [...])`).

The author read only the C# sources and the Dart README; whether TypeScript and Dart can express and read the plain form was not checked. (Checked in the codebase analysis of this task, 2026-11-11: both already write a list of one nested row of two `u8` as `010701000102`, pinned in their tests. The form exists there; only C# lacks a spelling.)

## Outcome

- In C# a `List` or `Dict` element can be a row of required members written with no flag byte, with the same bytes as the equivalent nested row in the other packages.
- A scheme author needs no wrapper class for it.

## Scope

### Included
- `Fields<T>` (and `Field`) gain the form for a list or dictionary element that is a nested row of members (the exact spelling is the package's: for example `f.List(x => x.Items, e => [e.Utf8(0, ...), e.U32(1, ...)])` where the element members are plain). Existing calls keep compiling and keep their bytes.
- The members of the new form are a scope of their own, as a nested row's are: ids from 0, a name may repeat a name of the row around it, references inside the element resolve inside it.
- Shared fixture (a list of 0, 1 and 3 such rows, strings and integers) run by every package that can express it; README C# section and the byte table.
- A check that Dart and TypeScript write and read the same bytes for the same fixture (and a finding when one of them cannot).

### Excluded
- Changing the bytes of any existing scheme or fixture; changing the flags form (a list of flags elements keeps working).
- Optional members in the new row form (a row that may leave a member out stays the flags form; the new form is required members only).
- A fixture run in the packages other than C#, TypeScript and Dart (Java, Go, Swift, Rust, Python, C++): they are not part of this task.
- Archangel's own scheme (changing it to the new layout is Archangel's change, after the next release).

## Acceptance Criteria

**AC-1: One form, no flag byte**
Given a C# row with `List<Item>` where `Item` has an id text, a text, a u32 and a text, all required
When the scheme is written with the new form and 3 items are packed
Then the bytes hold no flag byte per item and unpack returns 3 equal items; 0 and 1 items round-trip too (0 items packs `00 00` and the field after the list still reads).

**AC-1b: Dictionary values**
Given a C# row with `Dictionary<string, Item>` of the same four members
When the scheme is written with the new form and 2 entries are packed
Then each value's members follow its key with no flag byte, the keys keep the package's existing order, and unpack returns equal entries.

**AC-2: A missing required member is refused**
Given the AC-1 scheme and a row whose item leaves a member null, or a list holding a null item
When the row is packed
Then pack fails naming the member (or the element) and writes nothing for it.

**AC-3: Same bytes in every package**
Given the shared fixture
When C#, TypeScript and Dart pack the same entity
Then the hex is identical in all three (3 of 3), and each unpacks the others' bytes.

**AC-4: Nothing existing changes**
Given the current fixtures and golden vectors, and a list of flags elements
When the C# suite runs
Then 0 bytes differ from before, and the flags form still writes its flag byte (1 byte per element).

**AC-5: Typed and map rows, own scope**
Given the new form in a typed row and in a dictionary (map) row, with a member name that the outer row also uses
When the scheme is built, packed and unpacked
Then it builds, the typed row's element type needs the same public parameterless constructor as other row elements (the existing message when it is missing), the map row's items are dictionaries by member name, and unpack gives one row per item.

**AC-6: Documented**
Given the README C# section
When the new form is read
Then it shows the scheme, the bytes and says how it differs from the flags element (1 byte per element).

## Non-Functional Requirements

**Compatibility**
- Builds and passes on both targets of the package (`netstandard2.0` and `net10.0`); no change to the public spelling of existing members.

**Performance**
- The pack and unpack paths of existing schemes do not slow down: the existing timing and allocation tests still pass at their bounds.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | List of 0, 1 and 3 four-member rows: pack, unpack | No flag byte; equal rows; `00 00` for 0 and the next field still reads |
| AC-1b | Dictionary of 2 rows | Members follow each key with no flag byte; equal entries |
| AC-2 | Null member and null item | Pack fails naming the member or element |
| AC-4 | Existing golden and fixture suites; flags-element suite | 0 bytes differ; flags element writes 1 byte per element |
| AC-5 | Typed row and map row; repeated name; row type without constructor | Builds and round-trips; existing constructor message |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | Shared fixture: scheme and entity with 0, 1 and 3 rows | C#, TypeScript and Dart pack it | Identical hex in all three; each unpacks the others' bytes | Compatibility |
| AC-4 | Whole C# suite on both targets | Run the suite | 0 byte differences; timing bounds hold | Performance, Compatibility |
| AC-6 | README C# section | Read the example | Scheme, bytes and the 1-byte difference shown; the README example is run by a test where the README has such tests | — |

## Constraints

- The new form adds a spelling; it does not change how flags elements, wrapper-property groups or any existing scheme read or write.
- Every other package's behavior is unchanged: TypeScript and Dart only gain the fixture check (AC-3); if one of them cannot express or read the form, that is a finding and a new task, not a change inside this one.

## Risks & Mitigation

**Risk 1: An overload makes existing calls ambiguous**
- *Risk*: a lambda that returns a list of fields next to a lambda that returns one field can make existing `List`/`Dict` calls fail to compile.
- *Mitigation*: AC-4 compiles and runs the whole existing suite and the README examples; pick a spelling that leaves them untouched.

**Risk 2: Archangel keeps the extra byte until it ships**
- *Risk*: Archangel keeps the one-byte-per-comment layout until this ships; changing it later is another contract change on Archangel's side.
- *Mitigation*: accepted; nothing in Archangel waits for this task.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Whether TypeScript and Dart already express this form was not verified by the author | owner of this repository | resolved: both write a list of one nested row of two `u8` as `010701000102` (TypeScript duplicate-names test, Dart parity scheme-rows test); AC-3 pins the full fixture | Low |
| Archangel keeps the one-byte-per-comment layout until this ships; changing it later is another contract change on Archangel's side | Archangel owner | accepted-risk | Low |
| Optional members in an element row are not part of the new form (flags form stays the way to leave a member out) | owner of this repository | accepted-risk (listed under Excluded) | Low |
