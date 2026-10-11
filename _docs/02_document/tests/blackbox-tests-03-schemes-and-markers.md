# Blackbox Tests 3: Schemes, type bytes, markers

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

### FT-S-01: Scheme pack writes the type byte

**Summary**: A scheme with type number 32 packs that byte first. The row has no type member.
**Traces to**: AZ-1945 AC-1, AZ-1946 AC-1
**Category**: Bytes

**Preconditions**:
- Sid is 23

**Input data**: scheme type 32 and sid 23

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the row | two bytes |

**Expected outcome**: hex `2017`. Mismatched bytes 0.
**Max execution time**: 1s

### FT-S-04: Position golden has no type member

**Summary**: The position scheme does not add a type member. The golden hex stays 13 bytes.
**Traces to**: AZ-1945 AC-4, AZ-1946 AC-5, AZ-1949 AC-2
**Category**: Bytes

**Preconditions**:
- Motion flags are clear

**Input data**: position set

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack in each language | 13 bytes |

**Expected outcome**: hex `4001000065cd1d00a3e1110100`. Mismatched bytes 0.
**Max execution time**: 1s

### FT-S-06: Unknown buffer dispatches by the leading byte

**Summary**: An unknown buffer calls the handler whose scheme type matches the first byte. A duplicate type number fails before a read. An unknown byte calls no handler.
**Traces to**: AZ-1949 AC-1, AZ-1949 AC-4, AZ-1949 AC-5, AZ-1949 AC-6
**Category**: Bytes

**Preconditions**:
- Two schemes with distinct type numbers

**Input data**: hex `02070000000800000009000000`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack with both handlers | the matching handler runs |

**Expected outcome**: the handler for type 2 runs. An unknown leading byte returns the actual byte and runs no handler.
**Max execution time**: 1s

### FT-B-01: Marker bytes are the same in every language

**Summary**: The marker scheme packs sid, lat, lon, kind 1, kind id 0, title 0, and clear flags.
**Traces to**: AZ-1950 AC-1, AZ-1950 AC-6
**Category**: Bytes

**Preconditions**:
- Kind is 1, so kind id is present

**Input data**: sid 1, lat 500000000, lon 300000000, kind 1, kind id 0, title 0, flags clear

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack in each language | 17 bytes |

**Expected outcome**: hex `2001000065cd1d00a3e111010000000000`. Mismatched bytes 0.
**Max execution time**: 1s

### FT-B-05: A skipped order fails at scheme build

**Summary**: A value field numbered 2 in the first slot fails before any pack.
**Traces to**: AZ-1950 AC-5
**Category**: Bytes

**Preconditions**:
- The scheme is still being built

**Input data**: field id 2 as the first value field

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | construct the scheme | construction fails |

**Expected outcome**: no buffer. The scheme is not usable.
**Max execution time**: 1s

### FT-S-02: Unpack does not insert a type member

**Summary**: Unpacking a scheme drops the leading type byte and does not add a type field to the row.
**Traces to**: AZ-1945 AC-2, AZ-1946 AC-2
**Category**: Bytes

**Preconditions**:
- The packed bytes start with the scheme type

**Input data**: hex `2017`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack with the scheme | the row |

**Expected outcome**: sid is 23. The row has no type member.
**Max execution time**: 1s

### FT-S-03: A wrong leading byte is an error

**Summary**: A known scheme whose type is 32 rejects a buffer that starts with 33 and returns no row.
**Traces to**: AZ-1945 AC-3, AZ-1946 AC-4, AZ-1949 AC-3
**Category**: Bytes

**Preconditions**:
- The scheme type is 32

**Input data**: a buffer whose first byte is 33

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack | an error |

**Expected outcome**: expected byte 32, actual byte 33. No row.
**Max execution time**: 1s

### FT-S-05: The scheme is an argument, and a bad placement fails at build

**Summary**: Pack and unpack require the scheme. A type number that is not the scheme constructor argument fails at build. The row holds only data.
**Traces to**: AZ-1945 AC-5, AZ-1946 AC-3, AZ-1946 AC-6
**Category**: Bytes

**Preconditions**:
- The call site omits the scheme, or the type number is placed as a field

**Input data**: none

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build or call without a scheme | failure before a buffer write |

**Expected outcome**: the call does not compile, or Python raises. A rejected scheme does not pack.
**Max execution time**: 1s

### FT-S-07: The same bytes in all six languages

**Summary**: Each language suite packs the position golden and the marker hex with zero mismatched bytes.
**Traces to**: AZ-1945 AC-6, AZ-1946 AC-7, AZ-1949 AC-7, AZ-1950 AC-6
**Category**: Bytes

**Preconditions**:
- C#, TypeScript, Python, Rust, C++, and Java are present

**Input data**: position set and marker set

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack in each language | the shared hex |

**Expected outcome**: position `4001000065cd1d00a3e1110100`. Marker `2001000065cd1d00a3e111010000000000`. Mismatched bytes 0.
**Max execution time**: 1s

### FT-B-02: Kind id is present only when kind is 1

**Summary**: The when on kind writes kind id when kind is 1 and omits it otherwise.
**Traces to**: AZ-1950 AC-2
**Category**: Bytes

**Preconditions**:
- Kind id is the field after kind

**Input data**: kind 1, then kind 0

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack kind 1 | kind id bytes are present |
| 2 | pack kind 0 | kind id bytes are absent |

**Expected outcome**: kind 1 includes the kind id width. Kind 0 does not.
**Max execution time**: 1s

### FT-B-03: Flag bits use the child accessors

**Summary**: Hidden true and Delta absent sets the hidden bit and omits the delta payload.
**Traces to**: AZ-1950 AC-3
**Category**: Bytes

**Preconditions**:
- Hidden is the first flag and Delta is the second

**Input data**: Hidden true, Delta null

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | one flag byte |

**Expected outcome**: the hidden bit is set. The delta payload is absent.
**Max execution time**: 1s

### FT-B-04: A nested row restarts field ids at 0

**Summary**: A list element row uses its own field id 0. That id does not collide with the parent row.
**Traces to**: AZ-1950 AC-4
**Category**: Bytes

**Preconditions**:
- The parent scheme has a list of a row type

**Input data**: one element row

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build and pack | a buffer |

**Expected outcome**: the scheme builds. The element id 0 is not the parent id 0.
**Max execution time**: 1s

