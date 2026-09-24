---
loop: 4
branch: dev
---

# Type number

**Task**: AZ-1945
**Name**: Type number
**Description**: The packet type tag is one constant u8 on the scheme. It is not a field of the row.
**Complexity**: 5 points
**Dependencies**: AZ-1876_csharp_pack, AZ-1877_typescript_pack, AZ-1878_python_pack, AZ-1879_rust_pack, AZ-1880_cpp_pack, AZ-1881_java_pack
**Component**: library
**Tracker**: AZ-1945
**Epic**: pending

## Problem

Callers model the leading type tag as a normal field, so the row has to carry it. The tag is a constant of the scheme, and it is one byte.

## Outcome

- A type-number node writes one u8 and reads nothing from the value.
- `TypeNum` of 32 and a `u8` sid of 23 pack to `2017`.
- Unpack of `2017` yields sid 23 and no type member.
- Unpack of `2117` is an error: expected 32, actual 33, value count 0.
- The node is legal only as the first top-level item, once, with a value in `0..255`.
- All six languages produce the same bytes. Mismatched bytes: 0.

## API

The node has no field name. It does not appear in the value.

| Language | Construction |
|---|---|
| C# | `TypeNum.Set(32)` then `Field.U8("sid")` |
| TypeScript | `typeNum(32)` then `u8("sid")` |
| Python | `TypeNum.set(32)` then `u8("sid")` |
| Rust | `type_num(32)` then `u8("sid")` |
| C++ | `type_num(32)` then `u8("sid")` |
| Java | `TypeNum.set(32)` then `u8("sid")` |

This task adds the node to the existing untyped pack and unpack. `Scheme<T>` and `BinaryPacker` are the next task.

## Scope

### Included

- One constant leading u8, written on pack, checked on unpack.
- Rejection when the node is not first, appears twice, is nested under flags / when / repeat / group / list / dict, or is outside `0..255`.
- A scheme with no type number keeps today's layout. The golden position fixture is unchanged.

### Excluded

- `BinaryPacker` and `Scheme<T>`.
- Choosing a scheme by scanning the first byte of an unknown buffer.
- Storing the type tag as a u16.
- Removing a caller-supplied `u8` field. A scheme that also has that field writes both bytes.

## Acceptance Criteria

**AC-1: Constant u8 is not a value.**
Given type number 32 and sid 23, and a value that has `sid` only.
When packed with the existing pack function.
Then the bytes are `2017`.

**AC-2: Unpack drops the constant.**
Given `2017` and that scheme.
When unpacked.
Then sid is 23 and the value has no type member.

**AC-3: Wrong type byte.**
Given `2117`.
When unpacked.
Then the error carries expected `32` and actual `33`, and the value count is 0.

**AC-4: Absent type number.**
Given the golden position scheme and `fixtures/golden.hex`.
When packed and unpacked.
Then the bytes match the fixture.

**AC-5: Scheme rejected.**
Given a type number that is not first, a second type number, a nested type number, or a value above 255.
When the scheme is built.
Then construction fails before any byte is written.

**AC-6: Six languages.**
AC-1 and AC-3 bytes match across C#, TypeScript, Python, Rust, C++, and Java. Mismatched bytes: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-5 | four illegal type numbers | construction error |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | sid 23, type 32 | pack | `2017` | Compatibility |
| AC-2 | bytes `2017` | unpack | sid 23, no type member | — |
| AC-3 | bytes `2117` | unpack | expected 32, actual 33, 0 values | Reliability |
| AC-4 | golden fixture | pack | unchanged | — |
| AC-6 | AC-1 and AC-3 in all six | compare | 0 mismatched bytes | Compatibility |

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-1 and AC-3

**Reliability**
- A wrong type byte does not return a partial value

## Constraints

- The type number is one u8. It is not a u16.
- No generator and no registry.
- The node has no field name and is skipped by object binding.

## Risks & Mitigation

**Risk 1: The tag is written as two bytes**
- *Risk*: type 32 becomes `2000` and the fixture `2017` fails
- *Mitigation*: AC-1 requires `2017`
