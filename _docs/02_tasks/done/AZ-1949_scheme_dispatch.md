---
loop: 4
branch: dev
---

# Scheme dispatch

**Task**: AZ-1949
**Name**: Scheme dispatch
**Description**: `Scheme` is the only layout type. Every scheme has a mandatory type number. Unknown bytes pick a scheme by that leading byte and call a typed handler.
**Complexity**: 8 points
**Dependencies**: AZ-1946
**Component**: library
**Tracker**: AZ-1949
**Epic**: pending

## Problem

A WebSocket receiver does not know which row is in the buffer. Today it would read byte 0 and switch. `Packet` still exists beside `Scheme`, and the position layout still stores `type` as a field on the row. The type number has to be the scheme, and unpack has to perform that switch without a single return type that cannot name both rows.

## Outcome

- `Packet` and a `TypeNum` field node are gone. The layout type is `Scheme`. Pack and unpack are `BinaryPacker`. A value field takes an order id and a member accessor, not a name string.
- Every scheme is constructed with a type number in `0..255` and the fields. A scheme cannot be built without that number. The number is not a field and is not a member of the row.
- Pack writes that number as the first byte, then the fields. It does not read a `type` member.
- When the caller already has the scheme, unpack checks byte 0 against that scheme and returns the row. A mismatch returns expected and actual and no row.
- When the caller does not know the row, unpack takes the buffer and one handler per scheme. It reads byte 0, selects the scheme with that number, unpacks into that scheme's row type, and calls that handler. The handler parameter is the row type. No cast and no dictionary.
- Two handlers in one call with the same type number fail before any byte is read. A leading byte that matches no handler is an error and no handler runs.
- The position golden bytes stay `4001000065cd1d00a3e1110100`. The `0x40` is the scheme type number. The row has `sid`, `lat`, `lon`, `profile`, and the motion fields. It has no `type` member.
- All six languages produce the same bytes. Mismatched bytes: 0.

## API

C# is the reference. The other languages use the same shape. Casing follows the language. Rust and C++ still bind members at the scheme site. They do not add a generator.

```csharp
public sealed class UserModifiedEvent
{
    public int UserId { get; set; }
    public string UserNameChange { get; set; }
    public string UserEmailChange { get; set; }
    public byte UserStatusChange { get; set; }
}

public sealed class UserPositionEvent
{
    public int UserId { get; set; }
    public int Latitude { get; set; }
    public int Longitude { get; set; }
}

static readonly Scheme<UserModifiedEvent> ModifiedScheme = new(1, f => [
    f.I32(0, x => x.UserId),
    f.Utf8(1, x => x.UserNameChange),
    f.Utf8(2, x => x.UserEmailChange),
    f.U8(3, x => x.UserStatusChange)]);

static readonly Scheme<UserPositionEvent> PositionScheme = new(2, f => [
    f.I32(0, x => x.UserId),
    f.I32(1, x => x.Latitude),
    f.I32(2, x => x.Longitude)]);

BinaryPacker.Unpack(bytes, ModifiedScheme.On(ev => { }), PositionScheme.On(ev => { }));
Bound<UserModifiedEvent> known = BinaryPacker.Unpack(ModifiedScheme, bytes);
```

| Language | Scheme | Known unpack | Unknown unpack |
|---|---|---|---|
| C# | `new Scheme<T>(int typeNumber, Func<Fields<T>, Field[]> define)` | `BinaryPacker.Unpack(scheme, bytes)` → `Bound<T>` | `BinaryPacker.Unpack(bytes, scheme.On(Action<T>), ...)` |
| TypeScript | `scheme<T>(typeNumber, ...fields)` | `BinaryPacker.unpack(scheme, bytes)` → result of `T` | `BinaryPacker.unpack(bytes, scheme.on(handler), ...)` |
| Python | `Scheme(type_number, row_type, *fields)` | `BinaryPacker.unpack(scheme, data)` → row | `BinaryPacker.unpack(data, scheme.on(handler), ...)` |
| Rust | `Scheme::new(type_number, fields)` | `BinaryPacker::unpack(&scheme, bytes)` → `Result<T, _>` | `BinaryPacker::unpack_with(bytes, scheme.on(handler), ...)` |
| C++ | `Scheme<T>(type_number, fields)` | `BinaryPacker::unpack(scheme, bytes, len)` | `BinaryPacker::unpack(bytes, len, scheme.on(handler), ...)` |
| Java | `new Scheme<>(typeNumber, rowClass, fields)` | `BinaryPacker.unpack(scheme, bytes)` → `Bound<T>` | `BinaryPacker.unpack(bytes, scheme.on(handler), ...)` |

Python and Java take the row class because those runtimes do not reify `T`. The class is not a `type` field.

## Scope

### Included

- Delete `Packet` and the type-number field node in C#, TypeScript, Python, Rust, C++, and Java. Pack and unpack stay on `BinaryPacker`.
- Mandatory type number on every scheme. Pack always writes it. Unpack always consumes it before the fields.
- Handler dispatch for an unknown buffer, in all six languages.
- Position golden uses type number `0x40` and no `type` member. README examples follow that.
- Existing layouts that had no type byte get an explicit type number in their tests, and the expected bytes include that leading byte.

### Excluded

- A process-wide registry of schemes.
- Choosing a scheme from the row type with no scheme argument.
- A code generator or derive macro.
- Archangel call sites.

## Acceptance Criteria

**AC-1: Scheme replaces Packet.**
Given each language package.
When its public API is read.
Then `Packet` is absent, pack and unpack are `BinaryPacker`, and a scheme is constructed with a type number plus fields bound by accessor.

**AC-2: The row has no type member.**
Given a position row and scheme type number `0x40`.
When packed.
Then the bytes are `4001000065cd1d00a3e1110100` and the row type declares no `type` member.

**AC-3: Known scheme checks the leading byte.**
Given scheme type number 1 and a buffer whose first byte is 2.
When unpacked with that scheme.
Then the error is expected 1, actual 2, and there is no row.

**AC-4: Unknown buffer calls the matching handler.**
Given a modified-event scheme of type 1 and a position-event scheme of type 2, and a buffer that starts with 2.
When unpacked with both handlers.
Then only the position handler runs, and its argument has the position fields and no type member.

**AC-5: Unknown type number.**
Given those two schemes and a buffer that starts with 9.
When unpacked with both handlers.
Then neither handler runs, and the error carries actual 9.

**AC-6: Type numbers in one call are unique.**
Given two handlers whose schemes both use type number 1.
When the unpack call is built.
Then it fails before a byte is read.

**AC-7: Six languages.**
AC-2 and AC-4 bytes match across C#, TypeScript, Python, Rust, C++, and Java. Mismatched bytes: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | public API | no Packet, no BinaryPacker |
| AC-6 | two schemes with type 1 | construction of the call fails |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | position row, type 0x40 | pack | golden hex, no type member | Compatibility |
| AC-3 | scheme type 1, byte 2 | known unpack | expected 1, actual 2, no row | Reliability |
| AC-4 | types 1 and 2, buffer starts with 2 | handler unpack | only position handler | — |
| AC-5 | buffer starts with 9 | handler unpack | no handler, actual 9 | Reliability |
| AC-7 | AC-2 and AC-4 in all six | compare | 0 mismatched bytes | Compatibility |

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-2 and AC-4

**Reliability**
- A wrong or unknown type byte does not return a partial row and does not call a handler

## Constraints

- The six packages stay peers. No shared walker.
- Rust and C++ member access stays at the scheme site.
- The type number is one u8.

## Risks & Mitigation

**Risk 1: The type byte is written twice**
- *Risk*: the golden hex gains a second `40`
- *Mitigation*: AC-2 requires the existing golden hex
