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
| `Scheme` | type number, row class, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, or a flag bit whose flagByte is not read earlier in the same scope |
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

**State Management**: clear pack is stateless. Unpack keeps the flag bytes it reads in the call's own map, keyed by flag group, so a scheme holds no per-call state and is shared by threads (two threads, 200 000 unpacks each, in the race test). Source layout: `Walker.java` walks fields, `Containers.java` holds `list`, `dict` and `times`, `Scalars.java` the numbers, `SchemeOrder.java` the construction checks (id order, references, flag scope). A session keeps one send counter and one receive counter.

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

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Java it is a `ShortPacket` and the numbers differ by case: an absent or negative count reports `needed` as `Integer.MAX_VALUE`, invalid UTF-8 reports `needed` as the string length with `left` 0, and a zero-width `times`, `list` or `dict` round reports `needed` 0. A zero-width `times` round is labelled with the `times` field, a list or dict element with `""`. Counts stay `long` until compared with the bytes left.

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. `SchemeOrder.validate` runs `requireFlagBytes`; a violation is an `IllegalArgumentException` that names the bit by kind and id.

**Breaking changes for callers** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

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
