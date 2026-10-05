# Rust package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for a native node.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's Rust program.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme` | type number, fields by order id | scheme | No | a gap, a repeated id, a bad anchor, a reference to an id not yet walked, a `when`, count or flag-bit reference to an id outside the enclosing `repeat` or `times` body, or a flag bit whose flag byte is not read earlier in the same scope. Construction failures are panics that name the id |
| `BinaryPacker::pack` | scheme, row | bytes | No | integer does not fit |
| `BinaryPacker::unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch; never panics on bytes (see §7) |
| `BinaryPacker::unpack_with` | bytes, handlers | row or error | No | unknown leading byte |

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
| `start` / `start_with` | none, or 16 bytes | 16 bytes | No | a nonce length other than 16 opens 0 sessions |
| `join` | 16 bytes | the waiter | No | length other than 16 joins 0 sessions |
| `pack` | scheme, row | payload the same length as clear pack | No | pack before start or join produces 0 payloads |
| `unpack` | payload, scheme | the row, or the clear-unpack error | No | — |

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: yank the crates.io version.

## 5. Implementation Details

**State Management**: clear pack is stateless. A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime writes little-endian fields |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return `Err`, never a panic (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- References by name (map layout) are not scope-checked; only numeric ids are. The run-time zero-progress guard still stops a hang (AZ-2117)
- A bound list whose element is a bare flag bit panics at construction; no test covers it
- Pack `borrowed_count` still adds its bias unchecked (AZ-2118)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Rust it is `UnpackError::Short` with `needed` 0. A zero-width `times` round is labelled `"times"`; the `repeat` case is `UnpackError::Trailing`. A `packed` count goes through checked arithmetic (`packed_layout` in `walk/unpack.rs`), so a count of 2^63 or more, or one that overflows a 32-bit `usize`, is an error, not a wrap. `walk/element.rs` reads one `list` or `dict` element and rejects a zero-width one.

**Construction rules** (`field/order.rs`, for both the map layout and the typed `Scheme::new`):
- a `when`, a `sized`, `bits`, `packed` or `times` count, or a flag bit may only name an id inside its own `repeat` or `times` body, because each round reads into its own values
- a split-form flag bit must follow its flag byte, read earlier in the same scope; a flag byte read inside a `when` is not visible after it, and one outside a `repeat` or `times` body is not visible inside

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
