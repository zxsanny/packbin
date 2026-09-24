# TypeScript package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Vue, React, and Node.

**Architectural Pattern**: stateless functions over a scheme.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's client. Vue and React import this package. They do not get their own package.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `scheme` | type number, fields by order id | scheme | No | order is not the next index |
| `BinaryPacker.pack` | scheme, row | bytes | No | integer does not fit |
| `BinaryPacker.unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch |

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

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: deprecate the npm version.

## 5. Implementation Details

**State Management**: stateless.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime data view writes little-endian fields |

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
