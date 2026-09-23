---
loop: 2
branch: loop/2-strings-lists-dicts
---

# UTF-8 string

**Task**: AZ-1938_utf8_string
**Name**: UTF-8 string
**Description**: A string is a 2-byte count of the bytes that follow, then those UTF-8 bytes.
**Complexity**: 3 points
**Dependencies**: AZ-1876_csharp_pack, AZ-1877_typescript_pack, AZ-1878_python_pack, AZ-1879_rust_pack, AZ-1880_cpp_pack, AZ-1881_java_pack
**Component**: library
**Tracker**: AZ-1938
**Epic**: AZ-1937

## Problem

A fixed `bytes(n)` cannot hold a username whose size is part of the message. If the count includes its own 2 bytes, the next field starts inside the text.

## Outcome

- `zxsanny` packs to 9 bytes `07007a7873616e6e79`. The count is 7. Those 7 bytes are the name. The byte after them is the next field.
- An empty string packs to `0000`.
- A string of 65536 UTF-8 bytes writes 0 bytes and fails.
- A count of 7 with 2 bytes left returns an error and 0 values, needed 7, left 2.
- The six languages mismatch on 0 bytes for the 9-byte name.

## Scope

### Included

- One UTF-8 string field
- Count 0
- Count 65536 rejected
- A short buffer

### Excluded

- A list or a dictionary
- A count that is a separate integer field the caller already wrote
- Text that is not UTF-8

## System Under Test Boundary

`pack` and `unpack` in each of the six languages. No registry call.

## Acceptance Criteria

**AC-1: Name bytes**
Given the string `zxsanny`
When it is packed
Then the bytes are `07007a7873616e6e79` (9 bytes) and unpack returns `zxsanny`

**AC-2: Empty string**
Given an empty string
When it is packed and unpacked
Then the bytes are `0000` and the text length is 0

**AC-3: Over the count limit**
Given a string of 65536 UTF-8 bytes
When it is packed
Then 0 bytes are written and pack fails

**AC-4: Short string**
Given a count of 7 and 2 bytes remaining
When it is unpacked
Then the error names the field, needed is 7, left is 2, and the value count is 0

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-1

**Reliability**
- The 2-byte count is not part of the 7 payload bytes. A short string returns 0 values.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | unpack count 7 with 2 bytes left | error, needed 7, left 2, value count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `zxsanny` | pack and unpack in each language | 9 bytes `07007a7873616e6e79`, text `zxsanny` | Compatibility |
| AC-2 | empty string | pack and unpack | `0000`, text length 0 | — |
| AC-3 | 65536 UTF-8 bytes | pack | 0 bytes written, pack fails | — |
| AC-4 | count 7, 2 bytes present | unpack | needed 7, left 2, value count 0 | Reliability |

## Constraints

- The count is little-endian and is the number of payload bytes that follow it.
- No registry call.

## Risks & Mitigation

**Risk 1: The count includes itself**
- *Risk*: the next field starts two bytes early, inside the text
- *Mitigation*: AC-1 fixes the 9-byte layout, 2 count bytes plus 7 text bytes

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Project rule says the library adds no length prefix. This count belongs to the string field. | feature restrictions | resolved | Medium |

## Scenarios

S4, S5.
