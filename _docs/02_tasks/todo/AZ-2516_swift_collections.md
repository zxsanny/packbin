---
loop: 26
branch: dev
---

# Swift strings, lists, dicts and nested rows

**Task**: AZ-2516_swift_collections
**Name**: Swift strings, lists, dicts and nested rows
**Description**: Swift packs and unpacks `utf8`, counted lists, dictionaries, group and flags elements and nested-row groups as TypeScript.
**Complexity**: 5 points
**Dependencies**: AZ-2515
**Component**: swift
**Tracker**: AZ-2516
**Epic**: AZ-2223

## Problem

Strings, lists and dicts are the user-shaped rows (`user`, `listgroup`, `dictgroup` ring kinds). Swift needs them for full parity, with the map form reading nested dictionaries (U26 A), and the same bytes whether a row is a typed struct or a `[String: Any]`.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-12 (closes the no-value rows, U26 A); contributes to SW-2 (collections), SW-3, SW-15 (wrong element types); scenario S8 owned).

## Outcome

- README UTF-8, list and dictionary examples pack and unpack with 0 mismatched bytes.
- The map form reads a nested-row group from the nested dictionary; a typed row reads a nested struct; both give the same bytes.

## Scope

### Included

- `utf8` (u16 length; invalid UTF-8 refused on unpack as TypeScript), `list` (u16 count), `dict` (u16 count; keys written in unsigned UTF-8 byte order), group and flags elements, nested-row groups, dict keys not flattened, lone bytes/utf8/dict in a round.
- The SW-12 pin list: one Swift test per row (`nil` flags member, `nil` vs empty list/dict, the U11 count behind a clear `when`, the U26 A nested map), named in the batch report.
- Owns (exclusive write): `swift/**`

### Excluded

- Limits (AZ-2517)

## Acceptance Criteria

**AC-1: README collection examples (SW-2)**
Given README UTF-8, list and dictionary examples
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-2: Collection rows (SW-3)**
Given the TypeScript tests `list-element-kinds`, `list-group-elements`, `dict-keys-not-flattened`, `dict-non-plain-object`, `nested-group`, `lone-bytes-in-round`, `lone-dict-in-round`, `binding`, `value-fidelity`, `borrowed-count`
When ported to Swift
Then same hex or same refusal; disagreements 0

**AC-3: Nested map (SW-12, U26 A, S8)**
Given a nested-row group whose names repeat outer names, given as a nested `[String: Any]` and as a nested struct
When packed
Then the inner values come from the nested dictionary/struct, never the outer row; the two forms give the same bytes. Owner ruling 2026-10-14 (Go-4 A): a group in a map row is a nested `[String: Any]` both ways (pack reads it, unpack returns it nested); a flat key that names a member of a group whose nested map is not given is refused naming the field; a row `unpack` returned packs again to the same bytes

**AC-3b: Dict keys equal under normalization (SW-4 spirit, S2)**
Given a packet whose dict has two keys whose UTF-8 bytes differ but are canonically equal (NFC and NFD forms of the same text)
When unpacked
Then a thrown "dict key given twice" error naming the field (no row, no trap); packing a `[String: Any]` never merges keys silently. Owner ruling 2026-10-14

**AC-4: Ring payloads (SW-2)**
Given the `user`, `nested`, `listgroup`, `dictgroup`, `listflags` hex of `language-pair.sh` and the three `-short` hex
When unpacked and repacked in Swift
Then the same hex; the short ones throw with no row

**AC-5: No value in collections (SW-12, S8)**
Given a list and a dict member given as `nil` (typed getter, absent key, boxed `nil`) and as an empty array/dictionary, typed and map
When packed
Then `nil` is no value (flags bit clear, or refused naming the field where a value is required); empty is a value with count 0 written; typed and map give the same bytes

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | README table | README hex |
| AC-2 | ported rows | TypeScript outcome |
| AC-3 | nested map vs struct; flat key without nested map | same bytes, inner values; flat key refused |
| AC-3b | NFC and NFD dict keys | duplicate-key error |
| AC-4 | ring hex | round trip / refusal |
| AC-5 | `nil` vs empty, typed and map | no value vs count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-4 | ring (AZ-2522) | Swift in the ring | handoffs pass | — |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Swift follows the others (C#, Python, Rust, Java, Go). The D1b rows stay as documented: Swift copies TypeScript. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import or wrapper of another package. Standard library only in the walker. Unsafe flags 0, C targets 0.
- AZ-2515 left the per-round state keyed per round node: scope it per list or dict element. The map form of a round is aligned per-name arrays (`nil` for a skipped round). `[UInt8]` is a byte run, never a list (as Go's `[]byte`); a typed `[UInt8]` member bound to a list of u8 works.
- A Swift `Dictionary` has no order: dict keys are written in unsigned UTF-8 byte order (README `dict` row), not Swift `String` ordering, which differs for non-ASCII keys.
- Local runs are `swift test` at the repository root on the owner's Mac (Swift 6.3.3); Linux runs use `swift:6`. No language feature newer than Swift 5.9.
- Errors are thrown as the typed `PackbinError`; no trap escapes `pack`, `unpack` or scheme construction on any input. A u16 length or count read from input is checked against the bytes left before any storage is reserved; offsets use checked arithmetic.

- From AZ-2514 (loop 26): the element-kind check (an anchored group, `u2` or other kinds as a list or dict element, D2/D3 of loop 25) is built here, with the README schemes that use utf8, list and dict (AZ-2514 AC-2 remainder). `Condition.eq` takes only integers and `Bool`: no Double overload.

- From AZ-2515 (loop 26): rounds record which round nodes a typed row reached (`Reader.reached`); scope this per list or dict element. Map-form round names are arrays (entry i for round i, `nil` where a round skips the name); `unpackMap` gives `[Any?]` per name. Reuse `RoundHelpers.swift` in the tests and the `Counted.swift`/`Rounds.swift` machinery; do not build a parallel path.

## Risks & Mitigation

**Risk 1: Map value types**
- *Risk*: `[String: Any]` lists can arrive as `[Any]`, `[Int]`, `[String]` or `[Any?]`; dicts as `[String: Any]` or `[String: Int]`.
- *Mitigation*: Accept any Swift array (but `[UInt8]`) for a list and any dictionary with `String` keys for a dict; refuse other element types naming the field (SW-15); documented in the package docs.

**Risk 2: Trap on hostile collections**
- *Risk*: A count of 65 535 elements over a 3-byte buffer reserves storage or indexes past the end.
- *Mitigation*: Bounds-checked reader only; no capacity reserved from an input count before it is checked; AZ-2517 fuzzes this path.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Swift traps on overflow, out-of-range index and force unwrap | checked arithmetic and bounds-checked reads (Constraints) | open | High |
| Swift `String` equality is canonical equivalence: two dict keys whose UTF-8 bytes differ (NFC vs NFD) are one `[String: Any]` key, where TypeScript keeps two | owner ruling 2026-10-14: unpack refuses such a packet as "dict key given twice" (AC-3b) | resolved | Medium |
| Group map shape: TypeScript packs a group from nested or flat keys and unpacks flat; Go packs and unpacks nested (Go-4 A) | owner ruling 2026-10-14: Swift follows Go-4 A (AC-3); this row overrides fit decision 4 | resolved | Medium |
