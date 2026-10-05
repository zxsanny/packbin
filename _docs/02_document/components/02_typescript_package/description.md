# TypeScript package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Vue, React, and Node.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's client. Vue and React import this package. They do not get their own package.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `scheme` | type number, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, or a flag bit whose flag byte is not read earlier in the same scope |
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

**Rollback**: deprecate the npm version.

## 5. Implementation Details

**State Management**: clear pack is stateless. Source layout: `walker.ts` is the unpack walker, `pack-fields.ts` the pack walker (split out of `walker.ts` in loop 11), `flag-scope.ts` the construction check for flag bits. A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime data view writes little-endian fields |

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
- A `when` inside a `list` or `dict` element resolves its condition id against the top-level ids, because element-local ids restart at 0 (pre-existing)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In TypeScript it is a short-packet result built by `unreadable` in `walker.ts` (and `readUtf8` in `kinds.ts`): the counted field, `needed` 0, the bytes left. A `times` round uses the name of its first body field as the label, a list or dict element uses the list's name. `bits` keeps accepting a `u64` (bigint) count up to `Number.MAX_SAFE_INTEGER`; a bigint above that cannot be exact and fails as a bad count.

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. `scheme()` runs `validateFlagScopes` (`flag-scope.ts`) after `flatten`; a violation is a `RangeError`.

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
