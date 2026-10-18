---
loop: 35
branch: dev
---

# Rust: compact text in every string position

**Task**: AZ-2652_rust_compact_text
**Name**: Rust: compact text in every string position
**Description**: Rust writes and reads every string with the compact text format.
**Complexity**: 5 points
**Dependencies**: AZ-2647
**Component**: Rust package
**Tracker**: AZ-2652
**Epic**: AZ-2645

## Problem

The Rust package writes a string as a 2-byte count plus UTF-8 inside the walker. After this loop every string, including list elements and dictionary keys, must use the compact format and write the same bytes as the other seven packages.

## Outcome

- Pack and unpack of every string position use the contract's codec.
- The package's suites pass with the new bytes; speed and hostile checks hold.

## Scope

### Included
- Codec (tables from `fixtures/text/tables.json` embedded as constants or a generated source with a drift check, encoder with optimal parse, decoder) under `rust/src/walk/` behind `pack.rs` `FieldKind::Utf8` (301-316) and dict keys (342-370); `unpack.rs` (265-276, 290-318); typed binders `BoundField::utf8`, `list_utf8`, `dict_list_utf8`.
- Tests: rust/src/counted_tests.rs (:115,195), `hostile_tests.rs`, `hostile_tests/pack_cases.rs`: inline string hex replaced by vectors-file rows; a loader for `fixtures/text/vectors.txt`.
- Run: `cargo test` in `rust/` (no `cargo fmt` on files you do not own; the crate is not rustfmt-clean).

### Excluded
- README text and the C++/other packages (AZ-2658 and their tasks); `cases.txt` rows and ring scripts (AZ-2657); any change to non-string fields.

## Acceptance Criteria

**AC-1: Packs every vector**
Given `fixtures/text/vectors.txt` and the Rust package
When each `enc` row is packed as a string field
Then the bytes equal the row's expected bytes; mismatches 0 (CS-5, CS-7, CS-19)

**AC-2: Unpacks every vector**
Given the same rows
When the expected bytes are unpacked
Then the string equals the row's string; mismatches 0, including the escape, raw fallback, LOCK and number-mode rows (CS-5)

**AC-3: Every string position**
Given the `ref` rows (the `user` and `nested` packets) and a list element, a dictionary key, a dictionary value list, a `repeat`/`times` string and an optional string under `flags`
When each is packed and unpacked
Then the bytes equal the `ref` bytes, values round-trip, an absent optional field adds 0 bytes and an empty string adds 1 (S12, CS-6, CS-15)

**AC-4: Hostile and damaged payloads**
Given every `bad` row and, for 20 `flip` rows, each single bit of the payload flipped in a packet with a `u8` after the string
When the packet is unpacked
Then a `bad` row returns an error naming the field and 0 values; a flipped bit returns a string or an error naming the field, the `u8` after it is unchanged, nothing is read past the payload and nothing throws or traps (CS-8, CS-9, CS-10)

**AC-5: Limits and headers**
Given a text of 65,535 UTF-8 bytes, one of 65,536, payloads of 127 and 128 bytes
When each is packed
Then 65,535 is accepted and 65,536 refused naming the field; the count header is 1 byte at 127 and 2 bytes at 128; `maxBytes` still bounds the packet (CS-17, S8)

**AC-6: Invalid UTF-8 refused**
Given escape bytes and a raw-fallback payload that are not valid UTF-8
When they are unpacked
Then each is refused naming the field (CS-16, S5)

**AC-7: Dictionary keys**
Given a dictionary with string keys inserted in two different orders, and one with a repeated decoded key
When it is packed and unpacked
Then both orders give identical bytes (sorted by the key's UTF-8 bytes), the repeated key is refused as today (S10, CS-6)

**AC-8: Speed**
Given a 20-character Ukrainian string
When 100,000 pack-then-unpack round trips run on one core
Then they finish in ≤ 1 second (CS-11)

**AC-9: Existing behavior kept**
Given the package's current suites
When they run with the string vectors updated
Then packets with no string are byte-identical (the 13-byte position record, CS-4) and every non-string test passes unchanged

## Non-Functional Requirements

**Performance**
- AC-8 bound; decoding is bounded in time and memory by the payload length (at most 6 output bytes per payload byte plus 8).

**Reliability**
- No unpack input panics, throws past the package's error type, or reads out of bounds.

**Compatibility**
- Same public API; only the bytes of string fields change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | pack vs vectors loader | 0 mismatches |
| AC-2 | unpack vs vectors loader | 0 mismatches |
| AC-3 | `user`/`nested` packets and each position | bytes and values |
| AC-4 | bad rows and bit-flip sweep | error names field, next field intact |
| AC-5 | boundary lengths | accept/refuse and header size |
| AC-6 | invalid UTF-8 inputs | refused |
| AC-7 | dictionary order and duplicates | identical bytes, error on repeat |
| AC-8 | speed loop | within the bound |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | vectors file and ring driver | the `handoff` driver of this language packs the `user` packet | its bytes equal the `ref` row (the ring compares it with the other seven) | CS-7 |
| AC-4 | hostile `cases.txt` rows with strings (AZ-2657) | the package's hostile loader runs | every string row passes | CS-8, CS-9 |

## Constraints

- The wire format is the one in `_docs/02_document/contracts/library/compact-text.md` (AZ-2646). A language never invents a choice the contract fixes (tie-breaks, table order, pad bits).
- The encoder works on the UTF-8 bytes this package already produces for a string today, so lone-surrogate and invalid-input behavior of the language does not change (fit decision, feature-description).
- Positions: a string field, a list element, a dictionary key, a dictionary value that is a list of strings, a string under `repeat`, `times` or `flags` (scenario S12). Dictionary pairs are still sorted by the key's UTF-8 bytes before the keys are encoded; a repeated decoded key is refused (S10).


## Contract

Consumer of `_docs/02_document/contracts/library/compact-text.md` (document dependency) and of `fixtures/text/vectors.txt` (AZ-2647).


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire break: packets with strings written before this loop cannot be read | Owner accepted 2026-10-18 (no tag was ever published) | accepted-risk | Medium |
