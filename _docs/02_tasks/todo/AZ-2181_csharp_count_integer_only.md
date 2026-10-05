# C# a count must name an integer field

**Task**: AZ-2181_csharp_count_integer_only
**Name**: C# count source is an integer field
**Description**: A `Sized`, `Bits`, `Packed` or `Times` count that names a utf8, bytes, float or bool field fails `Scheme<T>` construction with an `ArgumentException`, instead of building and failing at pack or read.
**Complexity**: 2 points
**Dependencies**: AZ-2087_csharp_forward_refs (the construction-time check of what a count names)
**Component**: csharp
**Tracker**: AZ-2181
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (C18, G2), owner scope A on 2026-10-05.

- A count may name any value field earlier in its scope. Only the earlier-field rule is checked today.
- A utf8 count builds, and pack throws a raw `FormatException`. A bytes count builds, and pack throws a raw `InvalidCastException`. Neither names the field.
- A bool count builds and packs (`01 01 01`), but the scheme's own read returns `ShortPacket`: the packet it writes is not readable by the scheme that wrote it.
- Float counts (f64, and also f32 on reading the code; the ticket text lists only f64) build and work: pack rounds the float, and read rounds and clamps it (the existing hostile unpack tests pin that).
- README: "raw bytes whose length is an earlier integer" (`sized`), "N is an earlier integer" (`times`); `schema.md` line 19 says the same. A bool or a float is not an integer. Rust refuses a non-integer count; Java and C++ allow a bool.

## Outcome

- A count names an integer field or the scheme does not build.
- The error names the counted field and the field it takes its count from.
- Integer counts, their bytes and every existing valid scheme are unchanged.

## Scope

### Included
- The construction check for the count of `Sized`, `Bits`, `Packed` and `Times`.
- Refusing these count sources: utf8, bytes (including a `Sized` field), f32, f64, bool, `Bits` and `Packed` lists.
- Turning the existing float-count hostile unpack tests into construction-refusal tests.

### Excluded
- Which kinds a `when` condition may name (float, bytes, utf8, bool): AZ-2126_eq_bool_true_only.
- Java and C++ (they keep allowing a bool count until AZ-2126 decides); other packages.
- Hostile unpack of integer counts (negative, huge): unchanged.

## Acceptance Criteria

**AC-1: A non-integer count is refused for every counted kind**
Given a `Sized`, `Bits`, `Packed` and `Times` whose count names a utf8, a bytes, an f32, an f64 or a bool field (a bool inside `Flags`)
When `new Scheme<T>(...)` is called
Then it throws `ArgumentException` naming the counted field and the field it names as its count. Schemes built: 0.

**AC-2: Integer counts are unchanged**
Given counts that name u8, u16, u32, u64, i8, i16, i32, i64 or a `u2` slot, the route fixture, the golden row and every scheme in the README examples and the handoff driver
When they are built, packed and read
Then they build and the bytes are identical (route `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`, golden `4001000065cd1d00a3e1110100`).

**AC-3: The error comes at construction, not at pack**
Given the utf8, bytes and bool probes above
When the scheme is built
Then the error is raised at construction; no `FormatException`, `InvalidCastException` or `ShortPacket` can occur later because of such a count.

**AC-4: Hostile counts that still apply**
Given the hostile unpack cases for integer counts (negative, wider than the buffer, behind a clear flag bit)
When they are unpacked
Then they return the same errors as before.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every scheme that builds today with an integer count are unchanged. Schemes with a non-integer count stop building (they were unreadable, rounded or misread).

**Reliability**
- A scheme that builds can read the packets it packs.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each counted kind over each of utf8, bytes, f32, f64, bool | `ArgumentException` naming both fields |
| AC-2 | integer widths and a `u2` slot as count; route and golden fixtures | builds; bytes as listed |
| AC-3 | utf8, bytes and bool probes | construction error; no later raw exception |
| AC-4 | existing integer-count hostile cases | unchanged errors |
| AC-1 | the six existing f32 / f64 count hostile tests | rewritten to expect the construction error, not deleted |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | `fixtures/golden.hex`, route fixture, `language-pair.sh` rings | C# producer and consumer | 0 mismatched bytes | Compatibility |
| AC-4 | `fixtures/hostile/cases.txt` count cases | C# unpack | same results as before | Reliability |

## Constraints

- ADR-001: C# keeps its own checker; no shared code with Java or Rust.
- `ArgumentException` stays the construction error type; no public API change.
- Wire bytes in the ACs come from the ticket probes; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller scheme with a float or bool count stops building**
- *Risk*: such a scheme packed rounded counts or an unreadable bool packet.
- *Mitigation*: the message says the count must be an integer field; README upgrade note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| DECISION: whether a bool count stays allowed (Java and C++ allow it) is decided with AZ-2126. These ACs follow the recommendation, integer only everywhere. The owner confirms the option before implementation | owner (with AZ-2126) | open | Medium |
| Ticket text says only an f64 count works; reading the code, an f32 count also builds and reads (existing hostile tests use both). The spec refuses both, so those tests must be rewritten | implementer | open | Low |
