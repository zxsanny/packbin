# Java typed nested rows unpack to the declared child type; ids scoped per nested row

**Task**: AZ-2101_java_typed_nested_rows
**Name**: Java typed nested rows
**Description**: A typed nested-row `group` (and a row-typed list/dict element) unpacks into an object of its declared type created by a caller-supplied factory; field ids inside a nested row never shadow the parent's ids.
**Complexity**: 3 points
**Dependencies**: AZ-2089_java_forward_refs_bool (reference scope rules in `SchemeOrder`, repeat count fix), AZ-2077_java_unpack_state_per_call (per-call unpack state), AZ-2074_java_hostile_unpack (same files)
**Component**: java
**Tracker**: AZ-2101
**Epic**: AZ-2069

## Problem

Probes were reproduced against a copy of the sources at `d108141` with JDK 21 unless marked "code reading".

### Defect 1 — typed nested row unpack throws `ClassCastException`
- `Packbin.group(Getter, Setter, Field...)` (`java/src/main/java/packbin/Packbin.java:95-97` → `Field.java:238-255`, `nestedRow = true`) has no way to create the child object.
- On unpack, `Walker.unpackGroup` (`Walker.java:288-311`) calls `newChild` (`:313-319`). It reuses the member if it is non-null, otherwise it creates a **`HashMap`**. The children's typed setters then receive a `HashMap`.
- `BinaryPacker.newRow` (`BinaryPacker.java:74-87`) creates the root with its no-arg constructor, so a nested member is `null` unless the POJO initializes it.
- Probe:
  - `Outer { Inner inner; int tail; }`, `Inner { Integer v; }`.
  - Scheme `new Scheme<>(1, Outer.class, group(get(o -> o.inner), set((o, v) -> o.inner = (Inner) v), u8(0, get((Inner i) -> i.v), set((Inner i, v) -> i.v = …))), u8(0, get(o -> o.tail), set(…)))`.
  - Pack of `{inner: {v: 3}, tail: 4}` → 3 bytes `01 03 04` (correct).
  - Unpack → **`ClassCastException: class java.util.HashMap cannot be cast to class Probe2$Inner`**, thrown out of `BinaryPacker.unpack`.
- All Java nested-group tests use `Map` rows (`PackbinFieldsTest.java:55-98`, `PackbinTest.java:285-304` with a continuing `group(0, …)`), so CI never hit this.

### Defect 2 — nested row ids shadow parent ids
- Nested rows number their fields from 0 (scheme-field-order AC-3; `SchemeOrder.java:29-37` gives them their own scope at construction). At run time they share the parent's id-keyed `seen` map: `packGroup` passes `seen` on (`Walker.java:161-171`), and so does `unpackGroup` (`:297`). A nested field with id 0 overwrites the parent's id 0.
- Probe: `u8(0, profile)`, `group(get g, set g, u8(0, inner))`, `when(1, eq(0, 1), u8(1, shape))`. Row `{profile: 0, g: {inner: 1}, shape: 9}` → **`01 00 01 09`**. `shape` is written although `profile == 0`, because the condition read the nested `inner`. Unpack repeats the mistake, so the error is invisible in Java-only round trips. Every other package writes `01 00 01`.

### Defect 3 — row-typed list/dict elements unpack as `HashMap`
- `VarFields.unpackElement` (`VarFields.java:440-461`) unpacks any non-leaf element (e.g. a nested `group`) into `new HashMap<String, Object>()` (`:458-460`). A `List<Inner>` member then receives a `List<HashMap>` (code reading; probe pending in the first test of this task).

C# has the analogous binding defects (task 23). TypeScript keeps nested values separate per scope after task 22. C++ binds members by pointer-to-member at construction.

## Outcome

- **Public API addition (user-approved in the plan, C19)**: the nested-row `group` gains a child factory, e.g. `group(Getter get, Setter set, Supplier<?> create, Field... fields)`. Unpack creates the child with `create` whenever the member is `null`, then sets it through `set`.
- The existing `group(Getter, Setter, Field...)` stays for `Map` rows. On a scheme whose row class is not a `Map` (and below any typed nested group), it fails construction with `IllegalArgumentException` ("nested group on a typed row needs a child factory"). It never fails later with `ClassCastException`.
- A list/dict element that is a nested group creates each element with that group's factory.
- Each nested row has its own id scope at run time (its own `seen`), so `when`/counts in the parent see only parent fields, and nested ones see only fields of their own row.
- Bytes are unchanged for every existing test, golden vector and language pair. Only the Defect 2 case changes, to the bytes the other packages produce.

## Scope

### Included
- New `Packbin.group` overload with a child factory, and its validation at construction.
- `Walker.unpackGroup`/`newChild` and `VarFields.unpackElement`/`packElement` using the factory.
- Per-nested-row `seen` scope in pack and unpack.
- Javadoc for the new overload (the publish build runs `javadoc`).

### Excluded
- `repeat` with non-leaf children (fixed in task 20, Defect 7).
- Forward/outer reference rules (task 20).
- Java bytecode level (task 25: `--release 17`, Android API 26).
- Error labels (C15). Nested short-packet errors still report the nested order id (e.g. `"0"`).

## Acceptance Criteria

**AC-1: Typed nested row round-trips**
Given the Defect 1 scheme built with the factory overload (`Inner::new`)
When `{inner: {v: 3}, tail: 4}` is packed and the bytes are unpacked
Then the bytes are `01 03 04` and the row has `inner.v == 3` and `tail == 4`. No exception.

**AC-2: Missing factory on a typed row fails at construction**
Given the same scheme built with the old `group(get, set, …)` overload on `Outer.class`
When `new Scheme<>(…)` runs
Then `IllegalArgumentException`; 0 schemes are built.

**AC-3: Map rows unchanged**
Given every existing `Map`-row nested group test (`flagGroupSession`, `flagGroupShortLogin`, `flagGroupStoredZero`)
When run
Then they pass with the same bytes and the same `ShortPacket(field "0", needed 2, left 1)`.

**AC-4: Nested ids do not shadow parent ids**
Given `u8(0, profile)`, a nested group with `u8(0, inner)`, then `when(1, eq(0, 1), u8(1, shape))`
When `{profile: 0, g: {inner: 1}, shape: 9}` is packed
Then the bytes are `01 00 01` (no `shape`), and unpack leaves `shape` null. With `profile: 1` the bytes are `01 01 01 09`.

**AC-5: Row-typed list elements**
Given `list(get items, set items, group(identity(), ignore(), Item::new, u8(0, v)))` on a typed row with `List<Item> items = [{v:3},{v:4}]`
When packed and unpacked
Then the bytes are `01 02 00 03 04`, and `items` holds two `Item` objects with `v` 3 and 4.

**AC-6: Existing bytes unchanged**
Given `java/test.sh`, `fixtures/golden.hex` and `language-pair.sh`
When run
Then all pass with 0 mismatched bytes.

## Non-Functional Requirements

**Compatibility**
- `Supplier` (`java.util.function`) is available on Android API 24+, inside the API 26 floor. Source-compatible for existing callers using `Map` rows.

**Performance**
- `nfrRoundTripsWithinOneSecond` still passes. One extra map per nested row per call at most.

## Unit Tests

AC-1, AC-2, AC-4 and AC-5 must fail first.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | probe `Outer`/`Inner` with `Inner::new` | `010304`, round-trip; today `ClassCastException` |
| AC-2 | old overload on `Outer.class` | `IllegalArgumentException` at construction |
| AC-3 | `PackbinFieldsTest.flagGroup*` | unchanged |
| AC-4 | shadow probe, `profile` 0 and 1 | `010001` / `01010109`; today `01000109` |
| AC-5 | typed `List<Item>` with a group element | `0102000304`, two `Item`s |
| AC-6 | full `java/test.sh` | green |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | same scheme in TypeScript/Python via `language-pair.sh` (add the case if the CI owner agrees) | Java ↔ TS/Python | identical `010001` | AC-3 (project) |
| AC-6 | `fixtures/golden.hex` | Java pack/unpack | identical | AC-1/AC-2 |

## Constraints

- ADR-001: Java-only change; no shared walker.
- Public API: only the **addition** of the factory overload. No existing signature is removed.
- `Walker.java` is 497 lines. Keep every file ≤ 500 by moving nested-row handling (or the scalar codec) into its own file if needed.

## Risks & Mitigation

**Risk 1: Typed callers relying on a pre-initialized nested member**
- *Risk*: today a POJO that initializes `inner = new Inner()` works with the old overload; AC-2 would reject it.
- *Mitigation*: the error message names the factory overload. Alternatively, allow the old overload when the scheme can create the row and the member is non-null after `newRow`. Decide during implementation and record the choice in the README.

**Risk 2: Javadoc/publish build**
- *Mitigation*: run the `publish-inside.sh` Java bundle step locally (`PACKBIN_MAVEN_BUNDLE_ONLY=1`), or let the CI gate do it.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Loop 12 (AZ-2131 AC-2, owner 2026-10-05: accept the dependency): an empty nested row `group(get, set)` under a flag bit round-trips presence for Map rows; for typed rows it hits Defect 1 like every nested row. Add the typed empty-nested-row case to this task's tests | coordinator | open | Low |
| Public API change: new `Packbin.group(Getter, Setter, Supplier<?>, Field...)` overload, approved in the bug-fix plan (task 32 / C19). Must be noted in the README Java section and release notes. | user (plan 2026-10-05) | accepted-risk | Medium |
| Whether the old overload on a typed row should fail at construction (AC-2) or be allowed when the member is pre-initialized (Risk 1). | user | open | Medium |
| Defect 3 (row-typed list elements) was found by code reading, not probed. The AC-5 test must first be run on the current code to confirm the failure. | implementer | open | Low |

## Owner decision (2026-10-06)

DECIDED, the proposed default: the old overload on a typed nested row fails at construction (no pre-initialized exception); chosen by the owner by taking the proposed default. The open DECISION rows above are resolved by this section.
