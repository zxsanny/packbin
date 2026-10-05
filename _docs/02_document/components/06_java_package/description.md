# Java package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for a Java program.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's Java program. Kotlin is not this package.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme` | type number, row class, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, a flag bit whose flagByte is not read earlier in the same scope, a `when` or count that does not name an earlier integer or bool field in its scope, a `bool` or empty group that is not a direct flag bit, an empty `group(anchor)`, or a `repeat` / `times` inside a round (see §7) |
| `BinaryPacker.pack` | scheme, row | bytes | No | integer does not fit |
| `BinaryPacker.unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch; never throws on bytes (see §7) |

**Input DTOs**:

```
Value:
  fields: name to number, string, list, dictionary, or absence (required) — absence omits the field
```

**Output DTOs**:

```
Bytes:
  length: number — sum of present field widths
ShortPacket:
  field: string
  needed: number
  left: number
```

### Interface: PackSession

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `load` | 32 bytes | a session, or nothing | No | length other than 32 creates 0 sessions |
| `start` | none, or 16 bytes | 16 bytes | No | a nonce length other than 16 opens 0 sessions |
| `join` | 16 bytes | the waiter | No | length other than 16 joins 0 sessions |
| `pack` | scheme, row | payload the same length as clear pack | No | pack before start or join produces 0 payloads |
| `unpack` | payload, scheme | the row, or the clear-unpack error | No | — |

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: drop the Maven Central version from new consumers. Central does not delete a published version.

## 5. Implementation Details

**State Management**: clear pack is stateless. Unpack keeps the flag bytes it reads in the call's own map, keyed by flag group, so a scheme holds no per-call state and is shared by threads (two threads, 200 000 unpacks each, in the race test). Source layout: `Walker.java` walks fields, `Containers.java` holds `list` and `dict`, `VarFields.java` the counted fields and the `times` count, `Rounds.java` the `repeat` and `times` rounds, `Scalars.java` the numbers, `SchemeOrder.java` the construction checks (id order, references, bool and empty-group placement, flag scope). A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime writes little-endian fields |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return an error value, never an exception (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- A count may name a bool field and the scheme builds, but Java does not read a bool as a 0/1 count: pack throws `IllegalStateException` and unpack returns a `ShortPacket` (open on AZ-2126)
- A typed nested row, with or without fields, throws `ClassCastException` on unpack: the child row is created as a `HashMap` (AZ-2101). Empty nested-row presence round-trips on `Map` rows only

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Java it is a `ShortPacket` and the numbers differ by case: an absent or negative count reports `needed` as `Integer.MAX_VALUE`, invalid UTF-8 reports `needed` as the string length with `left` 0, and a zero-width `times`, `list` or `dict` round reports `needed` 0. A zero-width `times` round is labelled with the `times` field, a list or dict element with `""`. Counts stay `long` until compared with the bytes left.

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. `SchemeOrder.validate` runs `requireFlagBytes`; a violation is an `IllegalArgumentException` that names the bit by kind and id.

**Reference and placement rules** (loop 12). `SchemeOrder.validate` resolves references while it walks the fields, one scope at a time: the top level, each `repeat` or `times` round, each `list` or `dict` element, and each nested row (`group(get, set, ...)`). A `when` body, a `flags` bit and an anchored `group` belong to the scope they stand in. A `when` condition or a borrowed count (`sized`, `bits`, `packed`, the count of `times`) may name only an integer or bool field read earlier in its own scope (C++ `is_count_source`); a later field, or an outer field named from inside a round or element, is an `IllegalArgumentException` that names both ids. Construction also refuses:
- a `boolField`, or a group with no fields, that is not a direct bit of `flags(...)` or `flagByte().bit(...)`
- `group(anchor)` with no fields wherever it stands, including as a flag bit: it has no accessor, so its bit could never be set
- a `repeat` or `times` inside a `repeat` or `times` round, also inside a nested row there (per-round nested lists are AZ-2127). A `repeat` inside a `list` or `dict` element in a round still builds: the element is a row of its own

An empty nested row `group(get, set)` is allowed only as a flag bit and carries presence only: the bit is set when the member is present, and a set bit unpacks as an empty child row (`{g: {x: 1}}` comes back as `{g: {}}`).

**Bool bit**: the bit is set only for `Boolean.TRUE`; `false`, an absent value and any other value (`1`, `"true"`) leave it clear. A set bit unpacks as `Boolean.TRUE` in both the combined (`flags`) and the split (`flagByte`) form; a clear bit stores nothing. A split bit inside a `when` that is not taken is still set from the row on pack, and unpack tests the `when` first and never reads it (shared `bitwhen` vector: `{k:0, v:5}` packs `010001` and unpacks as `{k:0}`; `{k:1, v:5}` packs `01010105`).

**Repeat and times rounds** (loop 12, `Rounds.java`). A round packs item i of every body field's list, and a flag bit in the round is decided from that item. The `repeat` round count is the longest list among the body's value fields, looking through `flags`, flag bits, `when` and anchored groups. Each round removes the body's values from the call's `seen` map, so a `when` or count never matches an earlier round's value. Unpack keeps one list entry per round for every value field of the body, `null` where the round skipped it, so packing the unpacked row gives the same bytes. The `null` padding is one store per round, linear in the packet length.

**Breaking changes for callers** (loop 11; pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Breaking changes for callers** (loop 12; no wire change for a scheme that round-tripped):
- A `when` or count naming a later field, or an outer field from inside a `repeat` or `times` round, built before. It is now refused at construction.
- A `boolField` or an empty group outside a flag bit, `group(anchor)` with no fields anywhere, and a `repeat` or `times` inside a round are refused at construction.
- Unpack of a `repeat` or `times` puts `null` in a body field's list for a round that skipped it (`[7, null, 9]`, was `[7, 9]`).
- A flag bit inside a `repeat` is decided from the round's value; it was decided from the whole list, so `repeat(flags(bool))` packed clear bits.

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language

## 8. Dependency Graph

**Must be implemented after**: the golden fixture file

**Can be implemented in parallel with**: the other five language packages

**Blocks**: the first version tag, together with the other five language packages

## 9. Logging Strategy

| Log Level | When | Example |
|-----------|------|---------|
| none | the library returns the error | the caller logs the three error fields |

**Log format**: none inside the package

**Log storage**: none
