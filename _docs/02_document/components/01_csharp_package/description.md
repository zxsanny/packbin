# C# package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for .NET.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's server. The other language packages do not call this package. They meet at the golden fixture.

## 2. Internal Interfaces

### Interface: Packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme<T>` | type number, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, or a flag bit whose flag byte is not read earlier in the same scope |
| `BinaryPacker.Pack` | scheme, row | bytes | No | integer does not fit |
| `BinaryPacker.Unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch; never throws on bytes (see §7) |

**Input DTOs**:

```
Value:
  fields: name to integer, string, list, dictionary, or absence (required) — absence omits the field
```

**Output DTOs**:

```
Bytes:
  length: int — sum of present field widths
ShortPacket:
  field: string
  needed: int
  left: int
```

### Interface: PackSession

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Load` | 32 bytes | a session, or nothing | No | length other than 32 creates 0 sessions |
| `Start` | none, or 16 bytes | 16 bytes | No | a nonce length other than 16 opens 0 sessions |
| `Join` | 16 bytes | the waiter | No | length other than 16 joins 0 sessions |
| `Pack` | scheme, row | payload the same length as clear pack | No | pack before start or join produces 0 payloads |
| `Unpack` | payload, scheme | the row, or the clear-unpack error | No | — |

## 4. Data Access Patterns

No queries and no cache. The call does not store the packet.

**Seed data**: the golden hex file.

**Rollback**: unlist the NuGet version. The library has no schema migration.

## 5. Implementation Details

**State Management**: clear pack is stateless. A failed clear unpack does not change the next clear pack. Unpack state lives in one `Scope` per call (`Scope.cs`): the values read in the packet, or in one `repeat`/`times` round, `list` element or `dictionary` value, plus the flag bytes read there. A scheme holds no per-call state, so one scheme is shared by threads (two threads, 200 000 unpacks each, in the race test). A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime's little-endian primitive writes are enough |

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
- `u8` to `u32`, `i8` to `i32`, `f32` and `f64` are boxed as `double`; `u64` and `i64` are read exactly and boxed as `ulong` and `long`, so `UnpackResult.Values` holds those types for them (a breaking change for callers that read a 64-bit value straight from `Values`; callers going through the row type are unaffected). Exact types for the other kinds are AZ-2116
- A `Group` as a list or dictionary element throws `KeyNotFoundException` on unpack (AZ-2119). A `When` directly under combined `Flags` is dropped on pack (AZ-2120)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In C# it is a `ShortPacket(field, 0, left)` built by one helper, `InterimBadValue` in `Walker.Counted.cs`, so C15 changes one method. Absent or negative counts, invalid UTF-8 and zero-width `times`, `list` and `dict` rounds use it; the `repeat` case returns `TrailingBytes`. Counts are read as `long` and compared with the bytes left before any allocation; a `u64` above `long.MaxValue` is clamped and then fails as a short packet. In `when` comparisons a NaN, infinite or huge float equals nothing.

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. `Packbin.cs` `SchemeOrder` runs `FlagScopes.Validate`; a violation is an `ArgumentException`.

**Breaking changes for callers** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Potential race conditions**:
- Clear pack keeps no packet. A dropped session payload desynchronizes that direction. There is no tag.

**Performance bottlenecks**:
- AC-10 is the bound: 100000 position round trips ≤ 1 second on one core

## 8. Dependency Graph

**Must be implemented after**: the golden fixture file

**Can be implemented in parallel with**: the other five language packages

**Blocks**: the first version tag, together with the other five language packages

## 9. Logging Strategy

| Log Level | When | Example |
|-----------|------|---------|
| none | the library returns the error | the caller logs `field`, `needed`, and `left` |

**Log format**: none inside the package

**Log storage**: none
