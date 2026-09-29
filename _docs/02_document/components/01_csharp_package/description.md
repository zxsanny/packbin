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
| `Scheme<T>` | type number, fields by order id | scheme | No | a gap, a repeated id, or an anchor that is not the next value id |
| `BinaryPacker.Pack` | scheme, row | bytes | No | integer does not fit |
| `BinaryPacker.Unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch |

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

**State Management**: clear pack is stateless. A failed clear unpack does not change the next clear pack. A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime's little-endian primitive writes are enough |

**Error Handling Strategy**:
- A short field returns an error and zero values
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator

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
