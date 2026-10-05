# Python package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for tools and scripts.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's Python program.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme` | type number, row class, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, a `bool` that is not a direct child of `flags` or of a flag-byte bit, or a `group(anchor)` with no fields (see §7). Each is a `ValueError` naming the id; a ninth `flags` child already fails at `flags(...)` |
| `BinaryPacker.pack` | scheme, row | bytes | No | integer does not fit |
| `BinaryPacker.unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch; never raises on bytes (see §7) |

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

**Rollback**: yank the PyPI version.

## 5. Implementation Details

**State Management**: clear pack is stateless. A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime writes little-endian fields |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return `UnpackResult(ok=False)`, never an exception (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- The split-form construction rule below is not enforced in Python yet; it arrives with AZ-2100
- A `bool` under a flag-byte bit passes the bool rule below, but the split form does not round-trip it yet: unpack of the bit's field reaches the `_Bool` `pass` in `_unpack.py` (AZ-2100)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Python it is `ShortPacket(field, needed=0, left)` built by `_bad_value` in `_unpack.py`. A count error is labelled with the counted field's id, a `times` error with its anchor id, and a zero-width list or dict element or an invalid dictionary key with `""`. Session unpack removes the pad and then runs the same clear unpack.

**Construction rule**: in the other split-form languages a flag bit must follow its flag byte in the same scope (top level, one `repeat` or `times` round, or one `list` or `dict` element). Python does not check this at construction yet (AZ-2100).

**Bool rule** (loop 12, `_validate_order` in `_nodes.py`): a `bool` stands only as a direct child of `flags(...)` or as the field of a flag-byte bit. Anywhere else (top level, inside any `group`, also one under `flags`, inside `when`, `repeat` or `times`, or as a `list` or `dict` element) `Scheme(...)` raises `ValueError` naming its id. A `group(anchor)` with no fields has no accessor, so it can never carry `true`; `Scheme(...)` refuses it wherever it stands, inside `flags` too. `flags(...)` with a ninth child raises `ValueError` naming the anchor when it is declared. The bit is set only for `True`; `False`, a missing value and any other value (`1`, `"yes"`) leave it clear, and unpack gives `True` only when the bit is set.

**Breaking changes for callers** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.
- A `bool` outside `flags` (its value never reached the wire) and a `group(anchor)` with no fields now fail at construction (loop 12).
- A ninth `flags` child now fails at `flags(...)`, instead of at pack only when its value was present (loop 12).

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language. Python's bound is 2 seconds.

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
