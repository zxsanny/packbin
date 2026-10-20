# Blackbox Tests 2: Strings, lists, dictionaries, handoffs

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

### FT-U-01: UTF-8 name

**Summary**: The string `zxsanny` packs to 7 bytes (count 6, then 6 payload bytes) and unpacks to the same text.
**Traces to**: AZ-1938 AC-1; since loop 35 the compact text format: CS-7, CS-19
**Category**: Bytes

**Preconditions**:
- The field is a compact-text string: a count (a varint of 1 to 3 bytes holding the payload length), then the payload (contract `compact-text.md`)

**Input data**: string `zxsanny`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the string | 7 bytes |
| 2 | unpack those bytes | the text |

**Expected outcome**: hex `062bfcfee119b2` (count `06`, payload `2bfcfee119b2`, from `scripts/text/textfmt.py enc zxsanny`). Unpacked text `zxsanny`. Mismatched bytes: 0.
**Max execution time**: 1s

### FT-U-02: Empty string

**Summary**: An empty string is 1 byte: a count of zero and no payload.
**Traces to**: AZ-1938 AC-2; since loop 35: CS-15
**Category**: Bytes

**Preconditions**:
- The field is a compact-text string (count of 1 to 3 bytes, then the payload; a count of 0 has no payload)

**Input data**: empty string

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack | a value |

**Expected outcome**: hex `00` (1 byte; vector `enc.hand.empty`). Text length 0.
**Max execution time**: 1s

### FT-U-03: String over the count limit

**Summary**: A string of 65536 UTF-8 bytes does not produce a buffer.
**Traces to**: AZ-1938 AC-3; since loop 35: CS-17
**Category**: Bytes

**Preconditions**:
- The longest text is 65,535 UTF-8 bytes; the count header is a varint of 1 to 3 bytes (contract `compact-text.md`)

**Input data**: 65536 bytes of `a`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | a failure |

**Expected outcome**: bytes written 0.
**Max execution time**: 1s

### FT-U-04: Short string

**Summary**: A count of 7 with 2 bytes left is an error and 0 values.
**Traces to**: AZ-1938 AC-4
**Category**: Bytes

**Preconditions**:
- The buffer ends inside the string

**Input data**: count 7, 2 payload bytes

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack | an error |

**Expected outcome**: field named, needed 7, left 2, value count 0.
**Max execution time**: 1s

### FT-L-01: Two little-endian integers

**Summary**: A list of the integers 1 and 2 packs and unpacks to those two values.
**Traces to**: AZ-1939 AC-1
**Category**: Bytes

**Preconditions**:
- Each element is a little-endian 2-byte integer

**Input data**: `[1, 2]`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack | a list |

**Expected outcome**: hex `020001000200`. List `[1, 2]`.
**Max execution time**: 1s

### FT-L-02: Big-endian list element

**Summary**: One big-endian integer 1 packs to 4 bytes.
**Traces to**: AZ-1939 AC-2
**Category**: Bytes

**Preconditions**:
- The element is a big-endian 2-byte integer

**Input data**: `[1]`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | 4 bytes |

**Expected outcome**: hex `01000001`.
**Max execution time**: 1s

### FT-L-03: List leaves the next field

**Summary**: A one-element list does not consume the following byte.
**Traces to**: AZ-1939 AC-3
**Category**: Bytes

**Preconditions**:
- A counted list is followed by a 1-byte integer

**Input data**: list `[1]`, then `2`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack | two fields |

**Expected outcome**: hex `01000102`. List `[1]`. Following field `2`. Bytes left 0.
**Max execution time**: 1s

### FT-L-04: Empty list and a list past the limit

**Summary**: An empty list is `0000`. A list of 65536 elements writes 0 bytes.
**Traces to**: AZ-1939 AC-4
**Category**: Bytes

**Preconditions**:
- The element count is an unsigned 16-bit length

**Input data**: `[]`, and a list of 65536 elements

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the empty list | 2 bytes |
| 2 | pack 65536 elements | a failure |

**Expected outcome**: empty hex `0000`. The long list writes 0 bytes.
**Max execution time**: 1s

### FT-D-01: User value

**Summary**: The username, roles, and access lists pack to the 79-byte hex (compact text, since loop 35).
**Traces to**: AZ-1940 AC-1
**Category**: Bytes

**Preconditions**:
- Access values are lists of strings

**Input data**: username `zxsanny`, roles `user` and `dispatcher`, access as in AZ-1940

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | 79 bytes |
| 2 | unpack those bytes | the same fields |

**Expected outcome**: hex `01062bfcfee119b20200030ba818078a8b1ca4ed51800300056b6aa330b00100032b0128036ae9c80400032b012808106770735f66697803ea04800348516404ca25f0000200032b0128048bbc2c80` (the first byte `01` is the scheme number; each string is compact text; it was 103 bytes with a 2-byte count before loop 35). Bytes left 0. Mismatched bytes across the six languages: 0.
**Max execution time**: 1s

### FT-D-02: Key insert order

**Summary**: Inserting access keys as store, channel, map still matches the sorted hex.
**Traces to**: AZ-1940 AC-2
**Category**: Bytes

**Preconditions**:
- Dictionary pairs are written in UTF-8 key order

**Input data**: the AZ-1940 user value with keys inserted as store, channel, map

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | 79 bytes |

**Expected outcome**: mismatched bytes against FT-D-01: 0.
**Max execution time**: 1s

### FT-D-03: Unpack the user value

**Summary**: The 79-byte hex unpacks to the username, both roles, and the three access lists.
**Traces to**: AZ-1940 AC-3
**Category**: Bytes

**Preconditions**:
- The buffer is the FT-D-01 hex

**Input data**: the 79-byte user hex

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack | a value |

**Expected outcome**: username `zxsanny`, roles `user` and `dispatcher`, channel `[read]`, map `[read, gps_fix, set, edit]`, store `[read, write]`. Wrong fields 0. Bytes left 0.
**Max execution time**: 1s

### FT-D-04: Empty string, list, and dictionary

**Summary**: The scheme number and three empty counted fields are 6 bytes (1 + 1 + 2 + 2).
**Traces to**: AZ-1940 AC-4
**Category**: Bytes

**Preconditions**:
- The packet is an empty string, an empty list, and an empty dictionary

**Input data**: `""`, `[]`, `{}`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | 6 bytes |

**Expected outcome**: hex `010000000000`: scheme number `01`, the empty string `00` (1 byte), the empty list `0000`, the empty dictionary `0000` (before loop 35 the string had a 2-byte count).
**Max execution time**: 1s

### FT-D-05: Repeated dictionary key

**Summary**: The same key twice is an error and 0 values.
**Traces to**: AZ-1940 AC-5
**Category**: Bytes

**Preconditions**:
- The buffer repeats one dictionary key

**Input data**: a dictionary buffer with one key twice

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack | an error |

**Expected outcome**: value count 0.
**Max execution time**: 1s

### FT-H-01: User value handoff

**Summary**: Each language packs the user value and the next language unpacks those bytes.
**Traces to**: AZ-1941 AC-1
**Category**: Bytes

**Preconditions**:
- The six handoffs are C# to TypeScript, TypeScript to Python, Python to Rust, Rust to Java, Java to C++, and C++ to C#

**Input data**: the FT-D-01 user value

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack in the producer | the 79-byte hex |
| 2 | unpack that hex in the consumer | the same fields |

**Expected outcome**: wrong fields 0. Bytes left 0.
**Max execution time**: 1s

### FT-H-02: Nested dictionary handoff

**Summary**: A dictionary of lists of dictionaries packs to 49 bytes and unpacks in the next language.
**Traces to**: AZ-1941 AC-2
**Category**: Bytes

**Preconditions**:
- `map` is one row `op`=`gps_fix`. `store` is `op`=`read` and `op`=`write`

**Input data**: that nested dictionary

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack in the producer | 49 bytes |
| 2 | unpack that hex in the consumer | the same rows |

**Expected outcome**: hex `010200036ae9c8010001000209f908106770735f66697804ca25f000020001000209f9032b012801000209f9048bbc2c80` (the first byte `01` is the scheme number; it was 58 bytes before loop 35). Wrong fields 0. Bytes left 0.
**Max execution time**: 1s

### FT-H-03: Position record after the new fields

**Summary**: Each language still packs the position record to 13 bytes.
**Traces to**: AZ-1941 AC-3
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

