# C# scheme owns a copy of each flag-bit group

**Task**: AZ-2180_csharp_flag_group_clone
**Name**: C# scheme clones its flag-bit groups
**Description**: A `Scheme<T>` keeps its own copy of the bits behind each `FlagByte` / `Flags`, so a later `Bit(...)` call on the same handle cannot change a scheme that is already built.
**Complexity**: 2 points
**Dependencies**: AZ-2088_csharp_pack_fails_loudly (scheme owns its fields), AZ-2087_csharp_forward_refs
**Component**: csharp
**Tracker**: AZ-2180
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (C23; batch 2 review F1), owner scope A on 2026-10-05.

- A `FlagByte` handle holds one shared, growing list of bits. Every `Bit(...)` call adds a bit to that list. A scheme built earlier from the same handle reads the list on every pack, so it changes when a later scheme adds a bit.
- Probe: `FlagByte m`; S1 = `(m, m.Bit(A))` packs a row with A = 1 to `01 01 01`. After S2 = `(m, m.Bit(B))` is built, S1 packs the same row to `01 03 01`: flag bit 1 is set for B, which S1 never writes, so the packet has a bit with no payload.
- The same list is read and extended without a lock, so a pack on one thread can see a bit list that another thread is growing.
- AZ-2088 Outcome says "no `Field` or `Condition` changes after construction. One field or condition can safely be reused in many schemes." Its AC wording is met literally (fields and conditions are copied), but its Outcome sentence is not: the flag-bit group is still shared mutable state.
- The ticket text also says that replacing an element of the caller's `params Field[]` changes the layout. Reading the code, the scheme already copies that array (AZ-2088 AC-7). AC-3 pins it; see Flagged concerns.

## Outcome

- A built scheme packs and reads the same bytes for the rest of its life, whatever is done to a `FlagByte` handle or to the arrays passed in afterwards.
- One `FlagByte` handle, one `Flags` field or one flag-bit field can be reused in many schemes without one scheme changing another.

## Scope

### Included
- A copy of each flag-bit group per scheme at construction, in every place the group appears in that scheme (the flag byte, its bits and `Flags`), so within one scheme they still refer to each other.
- Tests for AC-1 to AC-5.

### Excluded
- How bits are numbered and counted when one handle is shared by several schemes (a ninth bit across schemes, field-order numbering): AZ-2135_split_bits_field_order. A copy keeps the bits the handle held at construction time, so bit numbering stays as today.
- Java (same sharing, AZ-2135); Rust no longer counts bits across schemes.
- Any public API change.

## Acceptance Criteria

**AC-1: A later scheme does not change an earlier one**
Given `FlagByte m`, S1 = `(m, m.Bit(A))` and a row with A = 1 and B present, which S1 packs to `01 01 01`
When S2 = `(m, m.Bit(B))` is built
Then S1 packs the same row to `01 01 01` again.

**AC-2: Any later `Bit` call leaves a built scheme alone**
Given S2 built from `m`, and the bytes it packs for a row
When another `m.Bit(...)` call is made, with or without a new scheme around it
Then S2 packs the same bytes for the same row.

**AC-3: Changing the caller's array changes nothing**
Given the `params Field[]` array passed to `new Scheme<T>(...)`, holding the flag byte and its bits
When an element of that array is replaced after construction
Then the scheme packs the same bytes as before the replacement.

**AC-4: Concurrent use stays correct**
Given S1 is packing the AC-1 row in a loop on several threads
When one other thread builds schemes from the same `FlagByte` handle at the same time
Then every S1 pack returns `01 01 01` and no pack throws.

**AC-5: Valid schemes and wire bytes are unchanged**
Given the golden row, the route fixture, every split-form flag byte scheme in the tests (top level, inside a `repeat` or `times` round, in a list element), a `Flags` field reused in two schemes, and an orphan flag bit
When they are built and packed
Then they build and the bytes are identical (`4001000065cd1d00a3e1110100` for the golden row, `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` for the route); the reused `Flags` packs the same bytes in both schemes; the orphan bit still fails construction with the same message.

## Non-Functional Requirements

**Performance**
- Copying happens once at construction; pack cost is unchanged (project AC-10 limit holds).

**Compatibility**
- Wire bytes of every scheme that is built and packed without a later `Bit(...)` call on a shared handle are unchanged.

**Reliability**
- A built scheme is immutable from the caller's side and safe to use from many threads.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | S1 / S2 over one handle, row A = 1 and B present | `01 01 01` before and after S2 is built (today `01 03 01`) |
| AC-2 | bytes before and after a further `Bit(...)` call | equal |
| AC-3 | replace an element of the caller's array after construction | bytes unchanged |
| AC-4 | parallel packs of S1 while schemes are built from `m` | all results `01 01 01`; no exception |
| AC-5 | golden, route, split-form shapes, reused `Flags`, orphan bit | bytes as listed; orphan bit refused as before |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | `fixtures/golden.hex`, route fixture, `language-pair.sh` rings (including the split-form `bitwhen` ring) | C# producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: C# keeps its own scheme code; do not share code with Java.
- `ArgumentException` stays the construction error type; no new public member.
- Wire bytes in the ACs come from the ticket probes; the worker re-derives them from a real run before writing the tests.

## Risks & Mitigation

**Risk 1: A caller extended an earlier scheme by adding bits to its handle later**
- *Risk*: that scheme used to grow a bit with no payload, which the peer misreads, so no correct consumer depended on it.
- *Mitigation*: README upgrade note in the loop 13 docs pass.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Bit numbering and the ninth-bit count across schemes sharing one handle stay as they are; AZ-2135 changes them to field order. A copy of the group as built can still carry bit slots from an earlier scheme on the same handle | AZ-2135 | open | Medium |
| Ticket text says replacing an element of the caller's `params Field[]` changes the layout; the code already copies the array at construction (AZ-2088 AC-7). AC-3 is a regression pin. If a real probe shows a change, treat it as an extra defect in this task | implementer | open | Low |

## Loop 17 result (2026-10-07)

Already held after AZ-2135 (batch 1): `FlagScopes.Bind` gives every read its own `FlagGroup` and a `FlagByte` handle holds no bit, so AC-1 to AC-5 hold; no clone was made because the `Flags` group object is never mutated after `Field.Flags(...)`. `FlagGroupCopyTests` (7) pin it; three of them fail on `68ca4f8`.
