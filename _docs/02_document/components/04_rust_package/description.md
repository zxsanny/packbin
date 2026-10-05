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
| `Scheme` | type number, fields by order id | scheme | No | a gap, a repeated id, a bad anchor, a reference to an id not yet walked, a `when`, count or flag-bit reference to an id outside the enclosing `repeat` or `times` body, a flag bit whose flag byte is not read earlier in the same scope, a 9th member in one `flags` or a 9th bit in one flag-byte read, a bool (an empty `group`) not directly inside `flags` or under a flag bit, a `repeat` inside a `repeat` or `times` round, or a `times` inside a `times` round (see §7). Construction failures are panics that name the field |
| `BinaryPacker::pack` | scheme, row | bytes | No | integer does not fit |
| `BinaryPacker::unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch; never panics on bytes (see §7) |
| `BinaryPacker::unpack_with` | bytes, handlers | row or error | No | unknown leading byte |
| `pack` | `MapScheme`, values by field name | bytes | No | `PackError::Missing` for a written field with no value; `PackError::Type` for a value that does not fit, a bool value other than 0 or 1, or a `"__repeat__"` value that is not `Value::Groups` |
| `unpack` | `MapScheme`, bytes | values by field name, or error | No | `UnpackError::Type` (another type number), `Short`, `Trailing`; never panics on bytes (see §7) |

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

**State Management**: clear pack is stateless. A session keeps one send counter and one receive counter. A `FlagByte` handle holds only its name: `MapScheme::new` gives each flag-byte read a slot and numbers its bits by field order, so one handle can build any number of schemes.

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
- The typed API has no flag-byte form (C18); a split flag byte is built with the map API (`MapScheme`, `pack`, `unpack`) or a raw `SchemeItem::Field`
- Map API: a `flags` group is on only when its own value, a direct integer, float, bytes, utf8, list or dict value, or one of its flag bits is present; values held only in `u2`, `sized`, `bits`, `packed`, a nested group or a `when` are dropped with no error, and a `times` or `when` as a `flags` member or flag-bit field is never written (AZ-2128)
- Map API: fields under a `flags`, `when` or `group` inside a `times` round are not aligned per round (`slice_times` slices only direct children); a `repeat` or `times` inside a `list` or `dict` element builds but does not round-trip (AZ-2086)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Rust it is `UnpackError::Short` with `needed` 0. A zero-width `times` round is labelled `"times"`; the `repeat` case is `UnpackError::Trailing`. A `packed` count goes through checked arithmetic (`packed_layout` in `walk/unpack.rs`), so a count of 2^63 or more, or one that overflows a 32-bit `usize`, is an error, not a wrap. `walk/element.rs` reads one `list` or `dict` element and rejects a zero-width one.

**Construction rules** (`field/order.rs` for ids and scope, then `check_shape` in `field/shape.rs` for flag bits, bools and rounds; `MapScheme::new` runs both, also for the typed `Scheme::new`):
- a `when`, a `sized`, `bits`, `packed` or `times` count, or a flag bit may only name an id inside its own `repeat` or `times` body, because each round reads into its own values
- a split-form flag bit binds to the latest read of its flag byte that it can see, earlier in the same scope; a flag byte read inside a `when`, a `flags` member or a flag bit is not visible after it, and one outside a `repeat`, `times`, `list` or `dict` body is not visible inside
- a bit's position is its order among the bits of that read, not the order of `bit()` calls; a second read of the same flag byte starts its own bits (as C++)
- one `flags` holds at most 8 members and one flag-byte read at most 8 bits (a bit inside a `when` counts against the same read); the 9th panics naming that field
- a bool (an empty `group`, typed `BoundField::bool_flag`) stands only directly inside `flags` or under a flag bit; at the top level, inside `when`, `repeat`, `times`, a plain group (also one under `flags`) or as a `list` or `dict` element it panics naming its id
- no `repeat` inside a `repeat` or `times` round and no `times` inside a `times` round, at any depth (also through `when`, `group`, `flags` or a flag bit); a `times` inside a `repeat` round stays allowed, and a `list` or `dict` element starts outside any round

**Bool** (loop 12): the bit is set only for true (typed `Some(true)`, map value `1`); `0` or no value leaves it clear, and a map value other than 0 or 1 fails pack with `PackError::Type`. A set bit unpacks as `Value::U8(1)` (typed `Some(true)`), under `flags` and under a flag-byte bit alike; a clear one is absent (`None`).

**Map `pack` / `unpack`** (public since loop 12, `walk/mod.rs`): values are keyed by field name. A `flags` byte or flag byte is computed from its fields on pack and returned under its own name on unpack as `Value::U8` of the byte read. Each direct field of a `times` takes and returns a `Value::List`, one item per round; `repeat` rounds are `Value::Groups` under `"__repeat__"` (no value packs no rounds). A flag bit inside a `when` that is not taken still sets its bit on pack; unpack checks the `when` first and never reads the field (`bitwhen` vector: `{k:0, v:5}` packs `010001`, `{k:1, v:5}` packs `01010105`).

**Breaking changes for callers** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Breaking changes in loop 12** (bytes of valid schemes are unchanged except where noted):
- A `FlagByte` handle no longer counts bits across schemes, and a second read of a flag byte no longer shares the first read's bits. A handle reused for a second scheme used to shift that scheme's bits.
- A map bool value `0` now leaves its bit clear (it set it before); a bool value other than 0 or 1, or a `"__repeat__"` value that is not `Value::Groups` (before: no rounds), fails pack with `PackError::Type`.
- A bool or empty group outside `flags` or a flag bit (it packed nothing and came back missing), a 9th `flags` member or flag-byte bit (a shift panic in debug, an aliased bit in release), a `repeat` inside a `repeat` or `times` round and a `times` inside a `times` round now fail at construction.
- A bool under a flag-byte bit now unpacks as set (it was missing).

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
