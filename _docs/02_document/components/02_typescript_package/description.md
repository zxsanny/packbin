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
| `scheme`, `new Scheme` | type number, fields by order id | scheme | No | a type number outside 0..255, a gap, a repeated id, an anchor that is not the next value id, a flag bit whose flag byte is not read earlier in the same scope, or a bool or empty group that is not directly in `flags` or a flag-byte bit (§7) |
| `flags`, `flagByte(...).bit` | fields | field | No | a ninth bit on one flag byte (§7) |
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

**State Management**: clear pack is stateless. Source layout: `walker.ts` is the unpack walker, `pack-fields.ts` the pack walker (split out of `walker.ts` in loop 11), `flag-scope.ts` the construction checks for flag bits (`validateFlagScopes`) and for where a bool or empty group may stand (`validatePresenceMarks`). A session keeps one send counter and one receive counter.

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
- A flags group with fields is on only when its own member or an `int`, `float`, `bytes`, `utf8`, `list` or `dict` child has a value (`scalarChildNames` in `kinds.ts`). Values only in `u2`, `bits`, `sized` or `packed` children leave the bit clear and are dropped (AZ-2128)
- `when(eq(boolId, false))` packs its body, but `false` is absent on the wire, so the package's own unpack never matches it and fails (AZ-2126)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time and memory bound set by the input length. It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In TypeScript it is a short-packet result built by `unreadable` in `walker.ts` (and `readUtf8` in `kinds.ts`): the counted field, `needed` 0, the bytes left. A `times` round uses the name of its first body field as the label, a list or dict element uses the list's name. `bits` keeps accepting a `u64` (bigint) count up to `Number.MAX_SAFE_INTEGER`; a bigint above that cannot be exact and fails as a bad count.

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. The `Scheme` constructor runs `validateFlagScopes` (`flag-scope.ts`) after `flatten`; a violation is a `RangeError`.

**Bool rule** (loop 12). A `bool` or an empty group is a mark with no bytes, only a flag bit. It is allowed only as a direct member of `flags` or the field of a flag-byte bit; anywhere else (top level, a non-empty group, `when`, `repeat`, `times`, a list or dict element) `validatePresenceMarks` throws a `RangeError` naming the member. Its bit is set only for `true` (`bitOn` in `fields.ts`): `false`, no value, and any other value (`1`, `"yes"`) leave it clear. Unpack sets the member to `true` only under a set bit; a clear bit leaves it out of the row. A ninth bit throws a `RangeError` when it is declared: `flags(...)` with nine fields, or the ninth `.bit(...)` on a flag-byte handle.

**Constructor** (loop 12). `new Scheme(typeNumber, fields)` runs every check: the type number (0..255), `validateFieldIds`, then `flatten`, `validateFlagScopes` and `validatePresenceMarks` on the flat list. `scheme(...)` only calls it, so both refuse the same schemes with the same message. `Scheme.fields` holds the flattened fields.

**Breaking changes for callers, loop 11** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Breaking changes for callers, loop 12**:
- A `bool` or empty-group mark that is `false` (or any value other than `true`) packs a clear bit (`0100`, was `0101`), as in Python. Unpack leaves the member out; it used to read `true`.
- A `bool` or empty group outside a flag bit is refused at construction. It never round-tripped: it always unpacked `true`.
- A ninth flag bit is refused when declared. Pack used to write it, and the package's own unpack then failed with trailing bytes.
- `new Scheme(...)` refuses what `scheme(...)` refuses, and its `fields` is the flattened list. The constructor used to run no check.

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
