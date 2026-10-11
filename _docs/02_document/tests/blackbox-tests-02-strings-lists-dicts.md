# Blackbox Tests 2: Strings, lists, dictionaries, handoffs

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

### FT-U-01: UTF-8 name

**Summary**: The string `zxsanny` packs to 9 bytes and unpacks to the same text.
**Traces to**: AZ-1938 AC-1
**Category**: Bytes

**Preconditions**:
- The field is a counted UTF-8 string

**Input data**: string `zxsanny`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the string | 9 bytes |
| 2 | unpack those bytes | the text |

**Expected outcome**: hex `07007a7873616e6e79`. Unpacked text `zxsanny`. Mismatched bytes: 0.
**Max execution time**: 1s

### FT-U-02: Empty string

**Summary**: An empty string is a 2-byte count of zero.
**Traces to**: AZ-1938 AC-2
**Category**: Bytes

**Preconditions**:
- The field is a counted UTF-8 string

**Input data**: empty string

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack | a value |

**Expected outcome**: hex `0000`. Text length 0.
**Max execution time**: 1s

### FT-U-03: String over the count limit

**Summary**: A string of 65536 UTF-8 bytes does not produce a buffer.
**Traces to**: AZ-1938 AC-3
**Category**: Bytes

**Preconditions**:
- The count is an unsigned 16-bit length

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

**Summary**: The username, roles, and access lists pack to the 103-byte hex.
**Traces to**: AZ-1940 AC-1
**Category**: Bytes

**Preconditions**:
- Access values are lists of strings

**Input data**: username `zxsanny`, roles `user` and `dispatcher`, access as in AZ-1940

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | 103 bytes |
| 2 | unpack those bytes | the same fields |

**Expected outcome**: hex `07007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465`. Bytes left 0. Mismatched bytes across the six languages: 0.
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
| 1 | pack | 103 bytes |

**Expected outcome**: mismatched bytes against FT-D-01: 0.
**Max execution time**: 1s

### FT-D-03: Unpack the user value

**Summary**: The 103-byte hex unpacks to the username, both roles, and the three access lists.
**Traces to**: AZ-1940 AC-3
**Category**: Bytes

**Preconditions**:
- The buffer is the FT-D-01 hex

**Input data**: the 103-byte user hex

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack | a value |

**Expected outcome**: username `zxsanny`, roles `user` and `dispatcher`, channel `[read]`, map `[read, gps_fix, set, edit]`, store `[read, write]`. Wrong fields 0. Bytes left 0.
**Max execution time**: 1s

### FT-D-04: Empty string, list, and dictionary

**Summary**: Three empty counted fields are 6 bytes.
**Traces to**: AZ-1940 AC-4
**Category**: Bytes

**Preconditions**:
- The packet is an empty string, an empty list, and an empty dictionary

**Input data**: `""`, `[]`, `{}`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | 6 bytes |

**Expected outcome**: hex `000000000000`.
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
| 1 | pack in the producer | the 103-byte hex |
| 2 | unpack that hex in the consumer | the same fields |

**Expected outcome**: wrong fields 0. Bytes left 0.
**Max execution time**: 1s

### FT-H-02: Nested dictionary handoff

**Summary**: A dictionary of lists of dictionaries packs to 58 bytes and unpacks in the next language.
**Traces to**: AZ-1941 AC-2
**Category**: Bytes

**Preconditions**:
- `map` is one row `op`=`gps_fix`. `store` is `op`=`read` and `op`=`write`

**Input data**: that nested dictionary

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack in the producer | 58 bytes |
| 2 | unpack that hex in the consumer | the same rows |

**Expected outcome**: hex `020003006d61700100010002006f7007006770735f666978050073746f72650200010002006f70040072656164010002006f7005007772697465`. Wrong fields 0. Bytes left 0.
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

