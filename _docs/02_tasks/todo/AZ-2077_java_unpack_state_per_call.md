# Java unpack keeps flags state per call, incl. the split flag-byte form

**Task**: AZ-2077_java_unpack_state_per_call
**Name**: Java thread-safe flags unpack
**Description**: Two threads unpacking with one shared scheme always get the correct rows, including the split `flagByte()` form.
**Complexity**: 2 points
**Dependencies**: None
**Component**: java
**Tracker**: AZ-2077
**Epic**: AZ-2069

## Problem

Schemes are built once and shared (`private static final Scheme<…>` in every test and in the README). The architecture NFR says "one call does not share state with another". Java unpack writes the flags byte it reads into the shared `FlagGroup`:

- `java/src/main/java/packbin/Field.java:323-349` `FlagGroup` has a mutable package field `int unpacked;` (line 325).
- `Walker.java:266-273` `unpackFlagByte` (split form `Packbin.flagByte()` + `fb.bit(...)`) stores `field.group.unpacked = …` (line 271).
- `Walker.java:275-286` `unpackFlagBit` decides presence from `field.group.unpacked` (line 282).
- `Walker.java:234-264` `unpackFlags` (combined `flags(...)` form) also stores `field.group.unpacked = flags` (line 246). It then iterates using the **local** `flags`, so the combined form is not affected today. The store is dead but invites the same bug.

**Reproduction (probe, copy of sources at `d108141`, JDK 21)**:
- `Field fb = Packbin.flagByte();` scheme `Maps.scheme(1, fb, fb.bit(u8(0, get("a"), set("a"))), fb.bit(u8(1, get("b"), set("b"))))`.
- `onlyA` = pack of `{a: 7}` → `01 01 07`; `onlyB` = pack of `{b: 8}` → `01 02 08`.
- Two threads × 200 000 unpacks each, expecting only `a = 7` / only `b = 8`: **11 593 wrong results out of 400 000**.
- The same probe with `flags(0, u8 a, u8 b)`: 0 wrong results.
- Existing tests check concurrent **pack** only (`PackbinFieldsTest.java:230-237`). The split form has **no Java test at all**.

Cross-language: C# fails in both forms (2 860 / 400 000, task 07). C++ keys flag bytes per walk (scope fix in task 09). TypeScript and Python keep flag bytes in per-call maps.

## Outcome

- `FlagGroup` holds only its bit list. Each flags byte read lives in per-call (per-scope) unpack state, so a `bit` field finds the byte its own `flagByte` read in the same call.
- The concurrent probe gives 0 wrong results for both forms.

## Scope

### Included
- Removing `FlagGroup.unpacked` and the store at `Walker.java:246`.
- Per-call storage of flag-byte values, scoped so a repeat round or list element with its own flag byte keeps its own value.
- First tests of the split form (pack, unpack, short packet, concurrency).

### Excluded
- `bool` placement rules and forward references (task 20).
- Nested-row id scoping of the `seen` map (task 32).
- The 8-bit cap: Java already enforces it at `Field.java:329`.

## Acceptance Criteria

**AC-1: Concurrent unpack, split form**
Given one shared scheme `flagByte()` fb, `fb.bit(u8 a)`, `fb.bit(u8 b)` and the packets `01 01 07`, `01 02 08`
When two threads each unpack one packet 200 000 times concurrently
Then all 400 000 calls return `null` (no error), and every row holds exactly the field its packet sets.

**AC-2: Concurrent unpack, combined form stays correct**
Given `flags(0, u8 a, u8 b)` and the same packets
When unpacked concurrently as in AC-1
Then 0 wrong results.

**AC-3: Scheme state does not change during use**
Given any scheme
When it packs and unpacks
Then no field of `Scheme`, `Field` or `FlagGroup` changes; `FlagGroup` has no mutable per-call member.

**AC-4: Split form matches the other languages**
Given the schema "split form": flag byte `motion`, then a `when(profile == 0)` group, then `motion.bit(u16 heading)`, `motion.bit(u8 speed)`, `motion.bit(i16 altitude)`
When a row with `heading = 90` is packed and unpacked
Then the `motion` byte is `01`, `5a 00` follows the group, the bytes equal the TypeScript/Python split-form bytes for the same row, and the row round-trips.

**AC-5: Existing bytes unchanged**
Given the golden fixture, the route fixture and all Java tests
When `java/test.sh` runs
Then all pass with identical bytes.

## Non-Functional Requirements

**Performance**
- `nfrRoundTripsWithinOneSecond` still passes. At most one small per-call structure for flag values.

**Compatibility**
- Android API 26 compatible APIs only (task 25 floor).

**Reliability**
- `BinaryPacker.unpack` is safe to call concurrently with one scheme.

## Unit Tests

AC-1 must fail on the current code.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the probe: 2 threads × 200 000, split form | 0 wrong, 0 errors |
| AC-2 | same with `flags(...)` | 0 wrong |
| AC-3 | reflection: `FlagGroup` declares no non-final instance field besides the bit list | passes |
| AC-4 | split form, `heading = 90` only | `motion` = `01`, `5a 00`, round-trip equal |
| AC-4 | split form, buffer ending inside `heading` | `ShortPacket` naming heading's label, handler not called |
| AC-5 | `PackbinTest`, `PackbinFieldsTest`, `FieldIdBindingTest`, `SessionTest` | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | `fixtures/golden.hex` | Java pack/unpack | identical hex | AC-10 |
| AC-5 | `language-pair.sh` Java ↔ other languages | handoff cases | 0 mismatched bytes | — |

## Constraints

- ADR-001: no shared code with the C# fix.
- No public API change. `FlagGroup` is package-private.
- `Walker.java` is 497 lines. Removing the stores frees lines; any new per-call holder must not push it past 500 (split by responsibility if needed).

## Risks & Mitigation

**Risk 1: Race test flakiness**
- *Mitigation*: 200 000 iterations produced 11 593 failures. Pair it with the deterministic AC-3 check.

**Risk 2: Split form semantics unclear without tests**
- *Mitigation*: write the AC-4 tests first from the schema split-form example and the TS/Python bytes.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Expected split-form bytes for AC-4 must come from the TypeScript/Python split-form tests, not be computed by hand. | implementer | open | Low |
