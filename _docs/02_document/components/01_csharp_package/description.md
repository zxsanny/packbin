# C# package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for .NET.

**Architectural Pattern**: stateless functions over a scheme.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's server. The other language packages do not call this package. They meet at the golden fixture.

## 2. Internal Interfaces

### Interface: Packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme<T>` | type number, fields by order id | scheme | No | order is not the next index |
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

## 4. Data Access Patterns

No queries and no cache. The call does not store the packet.

**Seed data**: the golden hex file.

**Rollback**: unlist the NuGet version. The library has no schema migration.

## 5. Implementation Details

**State Management**: stateless. A failed unpack does not change the next call.

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
- None. The functions do not keep a packet.

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
