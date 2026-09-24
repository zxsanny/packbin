---
loop: 4
branch: dev
---

# Scheme

**Task**: AZ-1946
**Name**: Scheme
**Description**: Pack and unpack take an explicit `Scheme<T>` plus a plain row. The row stays a data object.
**Complexity**: 8 points
**Dependencies**: AZ-1945
**Component**: library
**Tracker**: AZ-1946
**Epic**: pending

## Problem

A typed call that looks up a scheme from the row type fails only when that call runs, if the scheme was never defined. Putting the scheme on the row mixes a data object with the layout. The scheme is a separate value, and the call names it.

## Outcome

- The row type has data fields only. It has no scheme member, no interface, and no pack method.
- `BinaryPacker` pack and unpack take `Scheme<T>` and the row (or the bytes). The scheme argument is required.
- A call that omits the scheme does not compile in C#, TypeScript, Rust, C++, and Java. In Python the function requires the argument.
- Type number 32 and sid 23 pack to `2017` and unpack back to sid 23, with no type member on the row.
- There is no map from type to scheme, and no scan that checks every type has a scheme.
- The existing untyped `pack(packet, values)` functions stay, with the same signatures. The shipped name `Packet` stays on that path.

## Contract

Same two operations in every language. Casing follows that language. Success unpack yields `T`. A short buffer, trailing bytes, or a wrong type byte uses the error object that language already returns, and yields no row.

| Language | Pack | Unpack |
|---|---|---|
| C# | `byte[] BinaryPacker.Pack<T>(Scheme<T> scheme, T row)` | `Bound<T> BinaryPacker.Unpack<T>(Scheme<T> scheme, ReadOnlySpan<byte> bytes)` |
| TypeScript | `BinaryPacker.pack<T>(scheme: Scheme<T>, row: T): Uint8Array` | `BinaryPacker.unpack<T>(scheme: Scheme<T>, bytes: Uint8Array): UnpackResult<T>` |
| Python | `BinaryPacker.pack(scheme: Scheme[T], row: T) -> bytes` | `BinaryPacker.unpack(scheme: Scheme[T], data: bytes) -> UnpackResult[T]` |
| Rust | `BinaryPacker::pack(scheme: &Scheme<T>, row: &T) -> Result<Vec<u8>, PackError>` | `BinaryPacker::unpack(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError>` |
| C++ | `BinaryPacker::pack(Scheme<T> const&, T const&) -> vector<uint8_t>` | `BinaryPacker::unpack(Scheme<T> const&, uint8_t const*, size_t) -> UnpackResult<T>` |
| Java | `BinaryPacker.pack(Scheme<T> scheme, T row): byte[]` | `BinaryPacker.unpack(Scheme<T> scheme, byte[] bytes): Bound<T>` |

C# builds the scheme like this. The other languages use the same shape and the type-number spellings from task 04.

```csharp
public sealed class MarkerRow
{
    public byte sid { get; set; }
}

static readonly Scheme<MarkerRow> MarkerRowScheme = Scheme<MarkerRow>.Of(
    TypeNum.Set(32),
    Field.U8("sid"));

var row = new MarkerRow { sid = 23 };
byte[] bytes = BinaryPacker.Pack(MarkerRowScheme, row);
Bound<MarkerRow> back = BinaryPacker.Unpack(MarkerRowScheme, bytes);
```

`Scheme<MarkerRow>` does not accept a `Scheme` built for a different row type.

Field names on the scheme match public members on the row. C#, Java, Python, and TypeScript read and write those members by name. The row does not gain methods. Rust and C++ have no field reflection and this repo adds no generator: the scheme site passes the member (a pointer-to-member or a pair of accessors) together with the name. Those accessors are not methods declared on the row. The row struct still contains only `sid`.

## Scope

### Included

- `Scheme<T>` and `BinaryPacker` in all six languages.
- Round trip of type number 32 and sid 23 to `2017`.
- A compile failure, in each compiled language, for a pack call that passes the row and no scheme.
- Wrong type byte: expected 32, actual 33, no row.
- The golden fixture through the existing untyped pack.

### Excluded

- A registry, an assembly scan, or a checker that every type has a scheme.
- A code generator, derive macro, or annotation processor.
- An interface or static scheme member on the row.
- Dispatch that picks a scheme from the first byte without the caller passing a scheme.
- Renaming the existing untyped `Packet`.
- Archangel call sites.

## Acceptance Criteria

**AC-1: Pack takes the scheme.**
Given `MarkerRowScheme` and a row with sid 23.
When `BinaryPacker` packs that scheme and that row.
Then the bytes are `2017`.

**AC-2: Unpack takes the same scheme.**
Given `2017` and `MarkerRowScheme`.
When unpacked.
Then sid is 23 and the row has no type member.

**AC-3: The scheme argument is required.**
Given a pack call that passes a row and no scheme.
When that language compiles it (Python: when the call is type-checked, and when it is executed with one argument).
Then the build fails. Python raises `TypeError` for the missing argument. The failure is not a later lookup inside a successful call.

**AC-4: Wrong type byte.**
Given `2117` and `MarkerRowScheme`.
When unpacked.
Then expected is 32, actual is 33, and there is no row.

**AC-5: Untyped path.**
Given the golden position packet and fixture.
When packed with the existing untyped function.
Then the bytes still match the fixture.

**AC-6: The row stays data.**
Given the marker row type in each language.
When the test source is read.
Then the type declares `sid` and does not declare a scheme, a pack method, or a packer interface.

**AC-7: Six languages.**
AC-1 bytes match. Mismatched bytes: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | pack call with no scheme | compile error, or Python `TypeError` |
| AC-6 | marker row source | data field only |

AC-3 is a compiler invocation (`dotnet`, `tsc`, `cargo`, `g++`, `javac`) on a fixture that must fail. A runtime throw from inside pack does not satisfy it.

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | sid 23, type 32 | pack(scheme, row) | `2017` | Compatibility |
| AC-2 | bytes `2017` | unpack(scheme, bytes) | sid 23, no type member | — |
| AC-4 | bytes `2117` | unpack | expected 32, actual 33, no row | Reliability |
| AC-5 | golden fixture | untyped pack | unchanged | — |
| AC-7 | AC-1 in all six | compare | 0 mismatched bytes | Compatibility |

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-1

**Reliability**
- A wrong type byte or a short buffer does not return a partial row

## Constraints

- The scheme is an argument. There is no lookup table.
- Published untyped signatures stay source-compatible.
- Rust and C++ member access is written at the scheme site, not on the row.

## Risks & Mitigation

**Risk 1: The scheme is stored on the row**
- *Risk*: the data type gains a static layout and AC-6 fails
- *Mitigation*: AC-6 reads the row source

**Risk 2: Pack looks up a global scheme**
- *Risk*: a missing scheme becomes a runtime miss inside a call that compiled
- *Mitigation*: AC-3 requires the missing argument to fail the build
