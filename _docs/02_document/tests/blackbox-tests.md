# Blackbox Tests

## Positive Scenarios

### FT-P-01: Position pack

**Summary**: The position values pack to the 13-byte fixture.
**Traces to**: AC-1, R-08
**Category**: Bytes

**Preconditions**:
- The caller holds the position field list

**Input data**: position set in test-data.md

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the position values with motion flags clear | 13 bytes |

**Expected outcome**: hex `4001000065cd1d00a3e1110100`. Mismatched bytes: 0.
**Max execution time**: 1s

### FT-P-02: Position unpack

**Summary**: That hex unpacks to the same fields and omits motion.
**Traces to**: AC-2
**Category**: Bytes

**Preconditions**:
- FT-P-01 hex

**Input data**: position hex

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack the hex | a value |

**Expected outcome**: type 64, sid 1, lat 500000000, lon 300000000, profile 1. Motion field count: 0. Field mismatches: 0.
**Max execution time**: 1s

### FT-P-03: Six languages, one hex

**Summary**: All six languages emit the same bytes for the position list.
**Traces to**: AC-3, R-03
**Category**: Bytes

**Preconditions**:
- All six packages are built

**Input data**: position set

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack in each of the six languages | six buffers |

**Expected outcome**: byte mismatch count 0 across the six buffers.
**Max execution time**: 1s

### FT-P-04: Flags width

**Summary**: A clear bit adds nothing. A set uint16 adds two bytes.
**Traces to**: AC-4
**Category**: Bytes

**Preconditions**:
- A list whose bit 5 is a uint16

**Input data**: flags set

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack with flags 0x00 | buffer |
| 2 | pack with flags 0x20 | buffer |

**Expected outcome**: step 1 adds 0 bytes. Step 2 adds 2 bytes.
**Max execution time**: 1s

### FT-P-05: Zero is a value

**Summary**: A present 0 is written. Absence is not stored as 0.
**Traces to**: AC-5
**Category**: Bytes

**Preconditions**:
- The optional field is in the list

**Input data**: flags row for value 0

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack with that field set to 0 | buffer |
| 2 | pack with that field absent | buffer |

**Expected outcome**: step 1 sets the bit and stores integer 0. Step 2 leaves the bit clear.
**Max execution time**: 1s

### FT-P-06: Conditional group

**Summary**: The group is present only when the tested field matches.
**Traces to**: AC-6
**Category**: Bytes

**Preconditions**:
- A conditional group is in the list

**Input data**: groups set

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack when the tested field does not match | buffer |
| 2 | pack when it matches | buffer |

**Expected outcome**: step 1 adds 0 bytes. Step 2 adds exactly the group width.
**Max execution time**: 1s

### FT-P-07: Repeated group

**Summary**: A buffer that ends on a group boundary yields one value per group.
**Traces to**: AC-7
**Category**: Bytes

**Preconditions**:
- The list ends with a repeated group

**Input data**: groups set

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack a buffer whose length is a whole number of groups | a value |

**Expected outcome**: value count equals the number of complete groups.
**Max execution time**: 1s

### FT-P-08: First publish

**Summary**: The first matching tag publishes the six packages, each MIT, from one commit.
**Traces to**: AC-12, AC-13, AC-16, R-09, R-10, R-15, R-16
**Category**: Release

**Preconditions**:
- Golden mismatch count is 0
- All six languages are in the tagged tree

**Input data**: publish row 2

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | push a version tag | six registry publishes, including vcpkg `packbin` |

**Expected outcome**: exactly 6 packages from the same commit, license MIT, manual uploads 0. The registry host is not GitHub Packages.
**Max execution time**: 15 minutes

### FT-P-09: Tests on push and pull request

**Summary**: Every push and pull request runs the suite.
**Traces to**: AC-11, R-14
**Category**: Release

**Preconditions**:
- The GitHub repository is `https://github.com/zxsanny/packbin`

**Input data**: publish row 1

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | open a pull request whose tests fail | a failed check |

**Expected outcome**: the check runs. A failing test fails it.
**Max execution time**: 15 minutes

## Negative Scenarios

### FT-N-01: Short field

**Summary**: A buffer that ends inside a field returns an error and no value.
**Traces to**: AC-8
**Category**: Errors

**Preconditions**:
- flags 0x20 selects a uint16

**Input data**: flags row 4

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack a buffer that ends inside that uint16 | an error |

**Expected outcome**: the error names the field, the bytes it needed, and the bytes left. Value count: 0.
**Max execution time**: 1s

### FT-N-02: Leftover bytes

**Summary**: One byte left over after a group, or after the list, is an error.
**Traces to**: AC-7, AC-9
**Category**: Errors

**Preconditions**:
- The list is the repeated group, or a finished list

**Input data**: groups rows 4 and 5

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack a buffer with 1 leftover byte | an error |
| 2 | unpack a finished list plus 1 extra byte | an error |

**Expected outcome**: both return an error. Value count: 0.
**Max execution time**: 1s

### FT-N-03: Disagreeing tag publishes nothing

**Summary**: A tag whose languages disagree on the golden bytes publishes nothing.
**Traces to**: AC-14
**Category**: Release

**Preconditions**:
- Golden mismatch count is greater than 0

**Input data**: publish row 3

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | push that tag | no upload |

**Expected outcome**: packages published 0.
**Max execution time**: 15 minutes

### FT-N-04: Missing language publishes nothing

**Summary**: A registry whose language is absent from the tag gets no package.
**Traces to**: AC-15, R-05, R-17, R-18
**Category**: Release

**Preconditions**:
- The tagged tree has no Kotlin project

**Input data**: publish row 4

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | push the tag | the six packages, and no Kotlin package |

**Expected outcome**: packages published for Kotlin: 0.
**Max execution time**: 15 minutes

## Production Smoke Tests

| ID | Check | Target | Expected | Safe in prod |
|----|-------|--------|----------|--------------|
| SM-01 | Pack the position fixture with each published package | `pack` of the position values | hex `4001000065cd1d00a3e1110100` | yes |
| SM-02 | Unpack that hex in each published package | `unpack` | the five fields, motion field count 0 | yes |

### FT-P-10: C++ publish is a vcpkg git push

**Summary**: The C++ package on the first tag is vcpkg `packbin`, pushed as a git registry. It is not a pull request to the curated microsoft/vcpkg registry.
**Traces to**: AC-13, R-09, R-15
**Category**: Release

**Preconditions**:
- Golden mismatch count is 0
- The C++ project is in the tagged tree

**Input data**: publish row 2

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | push a version tag | a git push of the public vcpkg registry |
| 2 | `vcpkg install packbin` | the package imports |
| 3 | look for a pull request to microsoft/vcpkg | 0 pull requests |

**Expected outcome**: one vcpkg port `packbin` from the same commit as the other five. Manual uploads: 0.
**Max execution time**: 15 minutes

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

### FT-C-01: Width-2 list borrows the count

**Summary**: A packed list of width 2 takes its length from an earlier count and does not write that count again.
**Traces to**: 04_borrowed_count AC-1
**Category**: Bytes

**Preconditions**:
- An earlier `u8` count is 4

**Input data**: values `0, 1, 2, 3`, width 2, bias 0

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack in each language | one list byte |

**Expected outcome**: byte `e4`. The four values match. The count byte is not repeated inside the list. Mismatched bytes across the six languages: 0.
**Max execution time**: 1s

### FT-C-02: Width-1 list uses count minus one

**Summary**: Bias −1 packs eight 1-bits from a count of 9, and a count of 1 writes no bitset.
**Traces to**: 04_borrowed_count AC-2
**Category**: Bytes

**Preconditions**:
- The list width is 1 and the bias is −1

**Input data**: count 9 with eight bits of `1`, and count 1 with bias −1

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the eight bits | one bitset byte |
| 2 | pack count 1 | no bitset bytes |

**Expected outcome**: step 1 is byte `ff`. Step 2 writes 0 bitset bytes.
**Max execution time**: 1s

### FT-C-03: The counted group stops before the next field

**Summary**: Two latitude/longitude pairs are read, then the following `u8` is not another latitude.
**Traces to**: 04_borrowed_count AC-3
**Category**: Bytes

**Preconditions**:
- The group count is 2 and a `u8` follows the pairs

**Input data**: two lat/lon pairs, then `7`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack | both pairs and the trailing byte |

**Expected outcome**: both pairs match. The following byte is `7`. Bytes left: 0. The `7` is not a latitude.
**Max execution time**: 1s

### FT-C-04: One route scheme round-trips

**Summary**: One scheme packs the route fixture, unpacks it, and packs the same hex again.
**Traces to**: 04_borrowed_count AC-4
**Category**: Bytes

**Preconditions**:
- One row type and one scheme. No second scheme and no hand-appended bytes

**Input data**: sid 16, name 21, unit name absent, straight set, route id 45, count 2, kinds `[1, 3]`, latitudes `[500000000, 500010000]`, longitudes `[300000000, 300010000]`, straight bits `[1]`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack, unpack, pack again in each language | the same hex twice |

**Expected outcome**: both hex strings are `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`. Bytes left: 0. Schemes used: 1. Mismatched bytes across the six languages: 0.
**Max execution time**: 1s

### FT-C-05: A wrong length and a short tail fail closed

**Summary**: A list whose length is not the borrowed count fails, and a short coordinate tail returns no values.
**Traces to**: 04_borrowed_count AC-5
**Category**: Bytes

**Preconditions**:
- The borrowed count is already written

**Input data**: kinds whose length is not the count; then a count of 2 with one coordinate byte after the kinds

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the wrong-length list | packing fails |
| 2 | unpack the short tail | an error and no values |

**Expected outcome**: step 1 names the field. Step 2 names the field, the bytes needed, and the bytes left, and the value count is 0. No partial point and no partial kind.
**Max execution time**: 1s

### FT-O-01: A gap or a repeated id fails construction

**Summary**: Value fields must be 0, then 1. A second field numbered 2, or a repeated 0, builds no scheme and writes no bytes.
**Traces to**: scheme-field-order AC-1
**Category**: Bytes

**Preconditions**:
- The scheme is still being built

**Input data**: fields numbered 0 then 1; then a second field numbered 2; then two fields numbered 0

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build 0 then 1 | construction succeeds |
| 2 | build a second field numbered 2, or a repeated 0 | construction fails |

**Expected outcome**: step 1 builds one scheme. Step 2 builds 0 schemes and writes 0 bytes.
**Max execution time**: 1s

### FT-O-02: A continuing group anchor is the next value id

**Summary**: `repeat`, `when`, `times`, `flags`, or a continuing group takes an anchor equal to the next value id. The anchor is not a new slot. A different anchor fails.
**Traces to**: scheme-field-order AC-2
**Category**: Bytes

**Preconditions**:
- A value field numbered 0 is already in the list

**Input data**: anchor 1 with a first child numbered 1, then a child numbered 2; then an anchor that is not 1

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build the matching anchor | construction succeeds |
| 2 | build the mismatched anchor | construction fails |

**Expected outcome**: step 1 builds. The child after the first child is 2. Step 2 builds 0 schemes. The anchor is not written.
**Max execution time**: 1s

### FT-O-03: A nested list starts at 0

**Summary**: A list, a dict, or a nested group numbers its elements from 0. A value field after the list uses the next parent number. The list does not consume a parent number.
**Traces to**: scheme-field-order AC-3
**Category**: Bytes

**Preconditions**:
- The parent list is still being built

**Input data**: a list of one `u8` numbered 0, then a parent `u8` numbered 0

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build the scheme | construction succeeds |

**Expected outcome**: both numbers are 0. Schemes failed: 0.
**Max execution time**: 1s

### FT-O-04: Every Rust scheme build checks order

**Summary**: A raw field list with a gap fails. A `when` or a borrowed count that names an id not yet walked fails. No bytes are written.
**Traces to**: scheme-field-order AC-4
**Category**: Bytes

**Preconditions**:
- The Rust scheme is still being built

**Input data**: a raw list whose second value field is 2; a `when` or borrowed count naming id 9 before that id is walked

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build the gapped list | construction fails |
| 2 | build the missing reference | construction fails |

**Expected outcome**: both steps build 0 schemes and write 0 bytes.
**Max execution time**: 1s

### FT-O-05: The failure rule sits next to field order

**Summary**: The sentence after "Field order is wire order" names the gap, the repeated id, and the bad anchor, and says the anchor is not written.
**Traces to**: scheme-field-order AC-5
**Category**: Bytes

**Preconditions**:
- The order sentence is in the schema

**Input data**: the order sentence

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | read the next sentence | the failure rule |

**Expected outcome**: the sentence names a gap, a repeated id, and an anchor that is not the next value id, and it says the anchor is not written.
**Max execution time**: 1s

### FT-O-06: Anchors do not change a known packet

**Summary**: A scheme that already packed a known hex, updated only so each continuing group passes its anchor, keeps that hex in all six languages.
**Traces to**: scheme-field-order AC-6
**Category**: Bytes

**Preconditions**:
- The previous hex for that row is known

**Input data**: the same row, with anchors on the continuing groups

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack in all six languages | the previous hex |

**Expected outcome**: mismatched bytes: 0.
**Max execution time**: 1s

### FT-K-02: One connection round-trips

**Summary**: The opener sends 16 bytes, the waiter joins, and the waiter unpacks one packed position row.
**Traces to**: pack-session AC-2, AZ-2019 AC-2, AZ-2020 AC-2, AZ-2021 AC-2, AZ-2022 AC-2, AZ-2023 AC-2, AZ-2024 AC-2
**Category**: Bytes

**Preconditions**:
- Both sides load the same 32-byte seed

**Input data**: position row type 64, sid 1, lat 500000000, lon 300000000, profile 1, flags clear

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | opener starts and waiter joins those 16 bytes | both sessions are open |
| 2 | opener packs the row | payload length 13 |
| 3 | waiter unpacks that payload | the five fields |

**Expected outcome**: field mismatches 0. Added bytes 0.
**Max execution time**: 1s

### FT-K-03: The waiter sends

**Summary**: After one forward packet, the waiter packs the same row and the opener unpacks it.
**Traces to**: pack-session AC-3, AZ-2019 AC-3
**Category**: Bytes

**Preconditions**:
- FT-K-02 has already opened the connection

**Input data**: the same position row

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | waiter packs the row | a payload |
| 2 | opener unpacks it | the five fields |

**Expected outcome**: field mismatches 0.
**Max execution time**: 1s

### FT-K-04: A second packet on the same connection

**Summary**: A second row on the same direction unpacks as that second row.
**Traces to**: pack-session AC-4, AZ-2019 AC-4
**Category**: Bytes

**Preconditions**:
- One packet on that direction is already unpacked

**Input data**: sid 2, lat 1, lon 2, profile 3, flags clear

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack the second row | sid 2, lat 1, lon 2, profile 3 |

**Expected outcome**: field mismatches 0.
**Max execution time**: 1s

### FT-K-05: Two sessions stay apart

**Summary**: Two openers from one seed and two different 16-byte values do not recover each other's row.
**Traces to**: pack-session AC-5, AZ-2019 AC-5
**Category**: Bytes

**Preconditions**:
- The same 32-byte seed
- Two different 16-byte values

**Input data**: client A's packed position row, unpacked with client B's waiter

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack A's payload on B | not the original five fields |

**Expected outcome**: original rows returned 0.
**Max execution time**: 1s

### FT-K-06: A bad setup creates nothing

**Summary**: A seed whose length is not 32, or a join value whose length is not 16, creates no session.
**Traces to**: pack-session AC-6, AZ-2019 AC-6, AZ-2020 AC-4, AZ-2021 AC-4, AZ-2022 AC-4, AZ-2023 AC-4, AZ-2024 AC-4
**Category**: Bytes

**Preconditions**:
- No session is open yet

**Input data**: seed length 31, seed length 33, join length 15, join length 17

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | load or join each bad length | nothing is created |

**Expected outcome**: sessions created 0.
**Max execution time**: 1s

### FT-K-07: Pack before the connection is open

**Summary**: A loaded seed that has not started or joined produces no payload.
**Traces to**: pack-session AC-7, AZ-2019 AC-7
**Category**: Bytes

**Preconditions**:
- The seed is loaded
- Start and join have not run

**Input data**: the position row

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack | no payload |

**Expected outcome**: payloads produced 0.
**Max execution time**: 1s

### FT-K-08: The README shows clear pack and one session

**Summary**: The README keeps a clear pack example and shows one session that sends 16 bytes once.
**Traces to**: pack-session AC-8, AZ-2026 AC-1, AZ-2026 AC-2
**Category**: Bytes

**Preconditions**:
- The README is the published example

**Input data**: the README text

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | count clear pack examples and session examples | at least 1 clear, exactly 1 session |
| 2 | check the session example for load, start, join, pack, and unpack | each name appears |

**Expected outcome**: session examples 1. Missing operations 0. The session example has one 16-byte send.
**Max execution time**: 1s

### FT-K-09: Six languages, one session payload

**Summary**: Six openers with one seed and one 16-byte value pack the same 13-byte payload, and a waiter in another language unpacks it.
**Traces to**: AZ-2025 AC-1, AZ-2025 AC-2, AZ-2020 AC-1, AZ-2021 AC-1, AZ-2022 AC-1, AZ-2023 AC-1, AZ-2024 AC-1
**Category**: Bytes

**Preconditions**:
- One 32-byte seed and one 16-byte opener value in every language

**Input data**: the position row

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | each language's opener packs the row | six payloads |
| 2 | a waiter in another language unpacks one of them | the five fields |

**Expected outcome**: mismatched bytes among the six payloads 0. Length 13. Field mismatches 0.
**Max execution time**: 1s

### FT-E-01: The core builds the embedded way

**Summary**: The core builds the embedded way (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-1
**Category**: Resource

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: core sources with `-std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | compile for Cortex-M0+, Cortex-M4F, ESP32-S3 and ESP32-C3 | each build: errors 0, warnings 0 |

**Expected outcome**: each build: errors 0, warnings 0.
**Max execution time**: 60s

### FT-E-02: No heap and no exceptions in a firmware image

**Summary**: No heap and no exceptions in a firmware image (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-2
**Category**: Resource

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: one firmware using every field kind, linked with aborting malloc/new wrappers

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | link, then run on QEMU `mps2-an385` | `__cxa_throw` and `__cxa_allocate_exception` references 0; wrapper calls 0 |

**Expected outcome**: `__cxa_throw` and `__cxa_allocate_exception` references 0; wrapper calls 0.
**Max execution time**: 60s

### FT-E-03: The same bytes on the target CPU

**Summary**: The same bytes on the target CPU (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-3
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: every hex vector asserted in `cpp/tests/core` and `fixtures/golden.hex`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each row and unpack each hex on QEMU `mps2-an385` | differing bytes 0; differing fields 0; vectors run equals vectors asserted (213) |

**Expected outcome**: differing bytes 0; differing fields 0; vectors run equals vectors asserted (213).
**Max execution time**: 60s

### FT-E-04: The same bytes on a big-endian CPU

**Summary**: The same bytes on a big-endian CPU (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-4
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: the same vectors

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run the core test under QEMU user `s390x` | mismatched bytes 0; mismatched fields 0 |

**Expected outcome**: mismatched bytes 0; mismatched fields 0.
**Max execution time**: 60s

### FT-E-05: Flash and stack budget

**Summary**: Flash and stack budget (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-5, AZ-2078 AC-5, AZ-2081 AC-5
**Category**: Resource

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: the all-kinds firmware on Cortex-M4F

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | read `size` and `-fstack-usage` reports | core plus a 14-field table at most 8192 B of flash; deepest pack or unpack at most 512 B of stack; `.data` and `.bss` 0 B |

**Expected outcome**: core plus a 14-field table at most 8192 B of flash; deepest pack or unpack at most 512 B of stack; `.data` and `.bss` 0 B.
**Max execution time**: 60s

### FT-E-06: Errors are values

**Summary**: Errors are values (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-6
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a packet one byte short, one trailing byte, a wrong type number, an output one byte small, one group too many

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack or pack each | `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany`, each with offset and field id; bytes written past the offset 0; aborts 0 |

**Expected outcome**: `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany`, each with offset and field id; bytes written past the offset 0; aborts 0.
**Max execution time**: 1s

### FT-E-07: Scheme order is checked without throwing

**Summary**: Scheme order is checked without throwing (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-7
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a gap, a repeated id, a wrong anchor and a `when` naming an id not yet walked

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | compile a `constexpr` scheme; validate a runtime scheme | compile error naming the id; `SchemeInvalid` with that id; bytes written 0 |

**Expected outcome**: compile error naming the id; `SchemeInvalid` with that id; bytes written 0.
**Max execution time**: 1s

### FT-E-08: Strings and bytes are borrowed

**Summary**: Strings and bytes are borrowed (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-8
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a 40-byte `utf8` field and a 16-byte `bytes` field

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack into a `View` row; unpack into `Text<16>` | view points into the input with length 40, bytes copied 0; the fixed destination gives `TooMany` |

**Expected outcome**: view points into the input with length 40, bytes copied 0; the fixed destination gives `TooMany`.
**Max execution time**: 1s

### FT-E-09: `f64` needs an 8-byte double

**Summary**: `f64` needs an 8-byte double (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-9
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a build whose `double` is 4 bytes

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | compile a scheme with `f64`; compile one with `f32` only | a `static_assert` naming `f64`; the `f32` build succeeds (host stand-in until the avr-gcc task) |

**Expected outcome**: a `static_assert` naming `f64`; the `f32` build succeeds (host stand-in until the avr-gcc task).
**Max execution time**: 60s

### FT-E-10: The session runs on the board

**Summary**: The session runs on the board (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-10
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a 32-byte seed, a caller random function and the pack-session vectors

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run `start`, `join`, `pack` and `unpack` on QEMU `mps2-an385` | padded bytes equal the vectors; OS random references 0; a failing random function makes `start` return an error with 0 bytes padded |

**Expected outcome**: padded bytes equal the vectors; OS random references 0; a failing random function makes `start` return an error with 0 bytes padded.
**Max execution time**: 60s

### FT-E-11: Host programs use the core API

**Summary**: Host programs use the core API (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-11
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: `make test` in `cpp/`, the compile-fail check and the C++ side of the language pairs

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run on the host | failures 0; vectors dropped 0; 100000 round trips within 1 s; old walker references 0; each removed symbol has a README migration row |

**Expected outcome**: failures 0; vectors dropped 0; 100000 round trips within 1 s; old walker references 0; each removed symbol has a README migration row.
**Max execution time**: 10s

### FT-E-12: Installable from the embedded registries

**Summary**: Installable from the embedded registries (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-12
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a published tag

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | a fresh PlatformIO, Arduino-ESP32 and ESP-IDF project add packbin by name and build the README example | three builds succeed; local overrides 0; installed version equals the tag |

**Expected outcome**: three builds succeed; local overrides 0; installed version equals the tag.
**Max execution time**: —

### FT-E-13: Every target runs in CI

**Summary**: Every target runs in CI (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-13
**Category**: Resource

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a push to any branch

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | the `embedded` job of `test.yml` runs | one report row per target; a failing target fails the workflow |

**Expected outcome**: one report row per target; a failing target fails the workflow.
**Max execution time**: —

### FT-X-01: The hostile case file is well formed

**Summary**: The hostile case file is well formed (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2070 AC-1, AZ-2070 AC-2, AZ-2070 AC-3, AZ-2070 AC-4, AZ-2194 AC-1, AZ-2194 AC-2, AZ-2194 AC-3, AZ-2194 AC-9
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: `fixtures/hostile/cases.txt` (25 cases: 10 `unpack`, 8 `construct`, 2 `limit`, 5 `pack`), 18 corrupted copies of it, 7 corrupted copies of `fixtures/hostile/README.md` and a README copy without one section (26 corruptions in all, loop 18)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run `fixtures/hostile/cases.test.sh` (the `scaffold` job runs it) | `hostile cases ok: 25`; each of the 26 corrupted copies exits non-zero and names its line or its id; every id has a README section; a `pack` id also has `Scheme`, `Row`, `Run by` and `Not run by` lines that name each of the six packages exactly once |

**Expected outcome**: 25 ids pass; each of the 26 corrupted copies exits non-zero and names its line or its id; every id has a README section; a `bytes` line carries lowercase even hex starting `01`, a `pack_error` line carries `-`, and only the `pack` stage may use either term.
**Max execution time**: 5s

### FT-X-02: A reused flag-byte number keeps its own scope

**Summary**: A reused flag-byte number keeps its own scope (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2078 AC-1, AZ-2078 AC-2
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a scheme whose `times` items use `flag_byte(0)` like the outer scope

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack the row with the inner bit clear, then set | bytes `010101000203` and `0101000107`; both round-trip |

**Expected outcome**: bytes `010101000203` and `0101000107`; both round-trip.
**Max execution time**: 1s

### FT-X-03: A round that reads nothing ends the container

**Summary**: A round that reads nothing ends the container (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2078 AC-3
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: an empty `repeat`, bound and unbound, and bytes `01 05 09`; an unbound empty `times` with count `0xffffffff`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack | `TrailingBytes` at offset 2 and count 0; the `times` returns Ok at once |

**Expected outcome**: `TrailingBytes` at offset 2 and count 0; the `times` returns Ok at once.
**Max execution time**: 1s

### FT-X-04: The hostile vectors give allowed outcomes in C++

**Summary**: The hostile vectors give allowed outcomes in C++ (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2078 AC-4, AZ-2126 AC-3, AZ-2194 AC-8
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: 22 of the 25 cases in `fixtures/hostile/cases.txt`: the 10 `unpack` cases, the 8 `construct` cases (including `eq_bool_false`, built as `eq(0, 0)` at run time because the literal `eq(0, false)` is a compile error) and 4 of the 5 `pack` cases. Skipped with a printed reason: the 2 `limit` cases (C++ has no round limit, AZ-2220) and `pack_out_of_range_integer` (a typed row binds a `std::uint8_t`, so 300 cannot be written)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | the host runner builds each scheme by hand and unpacks, validates or packs it | each outcome is one the file allows (a `pack` case: the packet hex, or `BadValue` with no bytes); each case within 1 s; bytes written outside the row 0; every skipped case prints its reason |

**Expected outcome**: each outcome is one the file allows; each case within 1 s; bytes written outside the row 0; 22 cases run and 3 are skipped with a reason.
**Max execution time**: 22s

### FT-X-05: A bool or empty group outside flags is refused

**Summary**: A bool or empty group outside flags is refused (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2081 AC-1, AZ-2081 AC-2
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: schemes with a top-level `boolean`, an empty `group` at top level, in a `group`, a `when`, a `repeat`, a `times` and a `list`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build, then pack or unpack | compile error naming the id (`constexpr`); `SchemeInvalid` at run time with 0 bytes written |

**Expected outcome**: compile error naming the id (`constexpr`); `SchemeInvalid` at run time with 0 bytes written.
**Max execution time**: 1s

### FT-X-06: A bool inside flags is unchanged

**Summary**: A bool inside flags is unchanged (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2081 AC-3
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: `flags(boolean, u8)` with the bool true and false; `flag_byte` with `flag_bit(boolean)` true, false and absent

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack | `010307` and `010207`; `0101` and `0100`; unpack sets the bool only for a set bit |

**Expected outcome**: `010307` and `010207`; `0101` and `0100`; unpack sets the bool only for a set bit.
**Max execution time**: 1s

### FT-X-07: A u2 holds at most 64 children

**Summary**: A u2 holds at most 64 children (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2081 AC-4
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a `u2` with 64 and with 65 `u8` children

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build; for 64 pack and unpack | 65 fails construction; 64 packs to 16 bytes and round-trips |

**Expected outcome**: 65 fails construction; 64 packs to 16 bytes and round-trips.
**Max execution time**: 1s

### FT-X-08: `eq` on a bool accepts only `true`

**Summary**: A `when` whose `eq` names a bool or an empty-group mark fails scheme construction unless the compared value is `true`, in every package (loop 18, AZ-2126).
**Traces to**: AZ-2126 AC-1, AZ-2126 AC-2, AZ-2126 AC-3
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 18 (wave 1 construction check, wave 2 vector)

**Input data**: the scheme `flags(0, bool on)`, `when(1, eq(0, v), u8 v)` with `v` = `false` (and `0`, `2`, `-1`, `"yes"` where the language can write them); the hostile construct vector `eq_bool_false`; the same scheme with `eq(0, true)` and the rows `{on: true, v: 5}` and `{on: false}`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build the scheme with `eq(0, false)` | construction fails naming the `when` and field 0 (exception in C#, TypeScript, Python, Java and Rust; `SchemeInvalid` in C++, and the literal `eq(0, false)` is a compile error: `cpp/tests/compile-fail/when_eq_bool_false.cpp`) |
| 2 | build the same scheme with `eq(0, true)`; pack `{on: true, v: 5}`; unpack the bytes | hex `010105`; the row `{on: true, v: 5}` |
| 3 | pack `{on: false}` with the `eq(0, true)` scheme | hex `0100`; the `when` body is left out; unpack gives `{on: false}` |

**Expected outcome**: step 1 is `scheme_error` in all six packages (the vector `eq_bool_false`; C++ builds `eq(0, 0)` at run time); step 2 gives `010105` and the same row in all six; step 3 gives `0100`. Rust has no bool value: its bool is an empty group, `false` is `U8(0)` and `true` is `eq(id, 1)`.
**Max execution time**: 1s

### FT-X-09: A `when` or a count names an integer field only

**Summary**: A `when` may name an integer field or a bool (a bool only with `true`); a count (`sized`, `bits`, `packed`, `times`) may name an integer field only; any other source fails scheme construction in every package (loop 18, AZ-2126, owner decision 2026-10-06).
**Traces to**: AZ-2126 AC-1
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 18 (wave 1)

**Input data**: a `when` whose source is a float, a utf8, a bytes, a sized, a bits or a packed field; a `times`, `sized`, `bits` or `packed` count whose source is a bool, a float or another counted field; controls: a `when` on `u8`, `i64`, a `be()` field and a `u2` slot, a `when` on a bool with `eq(.., true)`, a count on `u8` and on a `u2` slot

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build each refused scheme | construction fails naming the `when` or the count and the source field |
| 2 | build each control scheme, pack a row and unpack it | the scheme builds and the row round-trips |

**Expected outcome**: every refused source gives `scheme_error`; every control builds and round-trips; a count that named a bool in Java, Rust and C++ is now refused (it was accepted); a float `when` in C# and TypeScript is now refused (it was accepted).
**Max execution time**: 1s

### FT-X-10: The pack stage of the hostile vectors

**Summary**: Five `pack` cases in `fixtures/hostile/cases.txt` give the same outcome in every package that can express them, and each package that cannot reports the case skipped with a reason (loop 18, AZ-2194).
**Traces to**: AZ-2194 AC-4, AZ-2194 AC-5, AZ-2194 AC-6, AZ-2194 AC-7, AZ-2194 AC-8
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 18 (wave 2); the file and its README pass FT-X-01

**Input data**: the five cases below (the scheme and the row are in the README section of each id, not in the file):

| Case | Scheme and row | Expected | Run by | Not run by |
|------|----------------|----------|--------|------------|
| `pack_out_of_range_integer` | `u8 a`; `a = 300` | `pack_error` (not wrapped to `2c`) | TypeScript, Python, Java, C# (dictionary rows), Rust (map form, `U16(300)`) | C++ (a typed row binds a `std::uint8_t`) |
| `pack_missing_required_value` | `u8 a; u8 b`; `a = 1` | `pack_error` | all six (C++: an unset `Opt` member gives `BadValue`) | none |
| `pack_times_list_too_long` | `u8 a; times(count a){ u8 x }`; `a = 2`, `x = [1, 2, 3]` | `pack_error` | all six | none |
| `pack_times_list_too_short` | same scheme; `a = 2`, `x = [1]` | `pack_error` | all six | none |
| `pack_aligned_round_row` | `repeat{ flags{ bool on, u8 n } }`; `on = [true, false, true]`, `n = [1, 2, 3]` | `bytes` `01030102020303` | all six | none |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | each package's vector test packs the row of every case in its `Run by` list | `pack_error`: pack throws (C#, Java, TypeScript, Python) or returns an error (Rust `PackError`, C++ `BadValue`) and returns no bytes; `bytes`: exactly the packet in the table |
| 2 | each package's vector test reaches a case in its `Not run by` list | the case is reported skipped with its reason; a package in `Run by` that cannot run its case fails |

**Expected outcome**: 25 of 25 cases pass in the packages that run them; the only skip is `pack_out_of_range_integer` in C++; the error type and message are not asserted; the 20 earlier cases (10 `unpack`, 8 `construct`, 2 `limit`) give the same results as before the stage existed.
**Max execution time**: 5s

### FT-X-11: A lone dictionary in a round is refused

**Summary**: A single dictionary given for a `Dict` name in a `repeat` or `times` round is refused naming the member, instead of being broadcast to every round or read as one round; one dictionary per round still packs (loop 18, AZ-2308).
**Traces to**: AZ-2308 AC-1, AZ-2308 AC-2, AZ-2308 AC-3
**Category**: Errors

**Preconditions**:
- C#, TypeScript, Python, Java and Rust as built in loop 18 (wave 1); C++ has typed array rounds, so the case does not apply

**Input data**: the scheme `u8 n; times(count n){ dict d { utf8 e } }`, and `repeat{ dict d { utf8 e } }`; the rows `{n: 2, d: {a: "x"}}` (a lone dictionary) and `{n: 2, d: [{a: "x"}, {b: "y"}]}`

| Package | Before loop 18 | After |
|---------|----------------|-------|
| C# | broadcast to every round | `ArgumentException` naming the member |
| TypeScript | object: broadcast; `Map`: an empty dictionary per round; `repeat`: one round | error naming the member (a `Map`, `Set` or `Date` is no dictionary) |
| Python | `times`: broadcast; `repeat`: one round, or `ValueError` | `TypeError` naming the member (also with count 0) |
| Java | broadcast (`times`) or one round (`repeat`) | `IllegalArgumentException` naming the member |
| Rust (map API) | n = 1 packed; n = 2 `Missing` | `PackError::Type` naming the member |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the lone-dictionary row with the `times` scheme and with the `repeat` scheme | an error naming `d`; no bytes returned |
| 2 | pack the list of two dictionaries | hex `010201000100610100780100010062010079` (`times`); `0101000100610100780100010062010079` (`repeat` with the same two rounds) |
| 3 | pack a dictionary outside any round; pack a lone `string` for a `utf8` name in a round | `010100010061010078`; the string goes to every round, as before |

**Expected outcome**: step 1 is an error naming the member in all five packages; step 2 gives the hex above and the bytes of a list of dictionaries are unchanged; step 3 is unchanged. Not specified: a lone byte buffer for a `Bytes` or `Sized` name in a round is refused in C# and broadcast in TypeScript, Python, Java and Rust (open owner question, batch 1 discovery 1).
**Max execution time**: 1s

### FT-X-12: A lone scalar in a Rust `times` goes to every round

**Summary**: A Rust map scheme with a `times` and a single scalar for a name in the round puts the scalar in every round, as TypeScript, Python, Java and C# do (loop 18, AZ-2311).
**Traces to**: AZ-2311 AC-1, AZ-2311 AC-2, AZ-2311 AC-3
**Category**: Bytes

**Preconditions**:
- Rust as built in loop 18 (wave 1); the bytes were read from a TypeScript run

**Input data**: the scheme `u8 n; times(count n){ u8 x, u8 y }`; the rows `{n: 2, x: 1, y: [4, 5]}`, `{n: 3, x: 1, y: [4, 5, 6]}`, `{n: 2, x: 1, y: 4}` (two lone scalars), `{n: 1, x: 1, y: 4}` (one round), `{n: 2, x: [1, 2], y: [4, 5]}` (a list per name) and `{n: 2, x: [1], y: [4, 5]}` (a list shorter than the count)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the first three rows with the Rust map API | `010201040105`; `0103010401050106`; `010201040104` |
| 2 | unpack `010201040105`, then pack the unpacked row | the same bytes |
| 3 | pack the one-round row and the per-round lists; pack the row with the short list | `01010104` and `010201040205`, as before; a pack error naming `x` (`Missing`), no bytes |

**Expected outcome**: steps 1 and 2 give the hex above and equal the TypeScript, Python, Java and C# bytes for the same row; step 3 is unchanged. `repeat` has no lone-scalar form in the map API.
**Max execution time**: 1s

### FT-X-13: A `when`, `times` or `repeat` member of `flags` is written

**Summary**: A `when`, `times` or `repeat` that is a member of a `flags` container (or sits in a group or flag-bit field under it) is written like any other value, and its bit is on exactly when it writes a value; all six packages give the same bytes and rows (loop 18, AZ-2120, AZ-2128; owner decision 10, option A).
**Traces to**: AZ-2120 AC-1, AZ-2120 AC-2, AZ-2120 AC-3, AZ-2120 AC-4, AZ-2120 AC-5, AZ-2128 AC-1
**Category**: Bytes

**Preconditions**:
- The six packages as built in loop 18 (wave 3); the reference rows are `_docs/03_implementation/flags_member_reference_cases_loop18.md` (about 60 hex-pinned cases over the schemes WA to R2, taken from a C# run; each package matches the table byte for byte). Typed rows and dictionary or map rows both give the table's bytes where the package has both.

**Input data**: six representative rows of the table (the other rows are in the table file: split form WS and TS, group form WG and TG, two-value bodies W2, T2 and R2, and the same-`flags` condition WE):

| Case | Scheme | Row | Packs to | Unpacks to |
|------|--------|-----|----------|-----------|
| W-true (AZ-2120 AC-3) | WA: `u8 mode; flags{ when eq(0,1){ u8 speed }, u16 heading }` | `mode=1 speed=7 heading=90` | `010103075a00` | the same row |
| W-false | WA | `mode=0 heading=90` | `0100025a00` | the same row |
| W-same-flags-true | WE: `flags{ u8 mode, when eq(0,1){ u8 speed } }` | `mode=1 speed=7` | `01030107` | the same row |
| T-0-rounds / T-2-rounds (AZ-2120 AC-4) | TA: `u8 n; flags{ times(count n){ u8 pt }, u16 heading }` | `n=0 heading=90`; `n=2 pt=[5,6] heading=90` | `0100025a00`; `01020305065a00` | the same rows |
| R-0-rounds / R-2-rounds (AZ-2120 AC-4) | RA: `u8 mode; flags{ u16 heading, repeat{ u8 pt } }` | `mode=1 heading=90`; `mode=1 pt=[5,6] heading=90` | `0101015a00`; `0101035a000506` | the same rows |
| R-two-values-unpack | R2: `repeat{ u8 pt, u8 pu }` | unpack `0101035a0005060708` | - | `mode=1 pt=[5,7] pu=[6,8] heading=90` |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | in each package pack each row | the hex of the table; the bit of the member is on exactly when a value is written (a `when` whose condition holds and whose body has a value; a `times` or `repeat` with at least one round) |
| 2 | in each package unpack each hex of the table (AZ-2120 AC-5: the packet one package wrote is read by every other) | the row of the table; a clear bit reads nothing |
| 3 | unpack, then pack the unpacked row | the same bytes (the row repacks) |

**Expected outcome**: `Mode=1, Speed=7, Heading=90` packs `01 01 03 07 5a00` in C#, TypeScript, Python, Rust, Java and C++ (it was `01 01 02 5a00` with `Speed` dropped, in all six); every row of the table gives its hex in all six packages; C++ also counts a `u2`, nested `flags` or `flag_bit` head as a present group value (AZ-2128 AC-1).
**Max execution time**: 1s

### FT-X-14: A set `flags` member that cannot be written fails; old packets and other shapes are unchanged

**Summary**: Where a `when`, `times` or `repeat` member of `flags` has its bit set but cannot be written in full, pack fails naming the missing value and returns no bytes; packets written before loop 18 still unpack; golden and route fixtures do not change (loop 18, AZ-2120, AZ-2128).
**Traces to**: AZ-2120 AC-6, AZ-2128 AC-2, AZ-2128 AC-3
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 18 (wave 3); the schemes are in `flags_member_reference_cases_loop18.md`

**Input data**: W2 (`flags{ when eq(0,1){ u8 speed, u8 extra }, u16 heading }`) with `mode=1 speed=7 heading=90` (`extra` missing); TA with `n=2 pt=[5] heading=90` (list too short); TA with `n=0 pt=[5] heading=90` (count 0, list given); R2 with `mode=1 pt=[5] heading=90` (`pu` missing); the old packets `0101025a00` (WA), `0100025a00` (TA), `0101015a00` (RA); the golden `4001000065cd1d00a3e1110100`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each of the four incomplete rows | a pack error naming `extra`, `pt`, `pt` (count 0 with a list given; the C# text is "holds 1 items, but the times count is 0") and `pu`; no bytes |
| 2 | unpack each old packet | no error; WA gives `mode=1 heading=90` (no `speed`), TA gives `n=0 heading=90`, RA gives `mode=1 heading=90` |
| 3 | pack the position golden and the route fixture | the bytes of FT-P-01 and FT-C-04, unchanged |

**Expected outcome**: step 1 is a pack error in all six packages (C++ also refuses a `times` count 0 with a non-empty list outside `flags`: batch 3 discovery 22, owner to confirm); step 2 unpacks without error; step 3 is byte-identical. A packet whose `times` count is above 0 but whose bit is clear (what the old packers wrote) unpacks to a row that no longer repacks (`missing pt`): an upgrade note, not a failure. Not specified: a split `flagByte` decides its `when` or `times` bit where the byte is read, so a condition written between the byte and the bit leaves the bit clear and the body is dropped (review finding C3, open owner question).
**Max execution time**: 1s

### FT-X-15: A flag byte inside a `flags` member or a flag-bit child is invisible to a later bit (C++)

**Summary**: A flag byte read inside a `flags` member or a flag-bit child is a conditional scope: a later flag bit outside it cannot bind to it, and binds to an outer byte when one exists (loop 18, AZ-2304; closes AZ-2135 for C++).
**Traces to**: AZ-2304 AC-1, AZ-2304 AC-2, AZ-2304 AC-3, AZ-2304 AC-4, AZ-2135 AC-2
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 18 (wave 1); `cpp/tests/core/flag_scope_host_tests.cpp` and two compile-fail cases

**Input data**: (a) `flags(0, group(u8 v, flag_byte(0), flag_bit(0, u8 x)))` then `flag_bit(0, u8 b)`; (b) `flag_byte(0)`, then `flag_bit(0, group(u8 v, flag_byte(1), flag_bit(1, u8 x)))` where the only byte 1 sits in the child, then `flag_bit(1, u8 b)`; (c) `flag_byte(0)`, then `flags(0, group(u8 v, flag_byte(0), flag_bit(0, u8 x)))`, then `flag_bit(0, u8 b)`; rows with `v = 3`, `x = 5`, `b = 7`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build (a) and (b) (`constexpr` and the host `validate`) | compile error, or `SchemeInvalid` naming `b` (field 2) with 0 bytes written |
| 2 | pack and unpack scheme (c) with `b` only, `v` and `b`, `v`, `x` and `b` | `01010007`, `010101030007`, `01010103010507` (also `010001030105`, `0100010300`, `010000` for the rows without `b`); each unpacks to the row and repacks to the same bytes; the variant with the outer byte 1 guarding a flag-bit child gives the same bytes for its rows |
| 3 | build the golden, the route and the motion examples and every scheme in `cpp/tests` | bytes and results unchanged; the embedded flash stays within its budget |

**Expected outcome**: step 1 refuses (a) and (b) as Rust, TypeScript and Java do (compile-fail cases `flag_byte_in_flags_member.cpp` and `flag_byte_in_flag_bit_child.cpp`); step 2 gives the hex above, equal to the Rust and TypeScript bytes; step 3 is unchanged (the flash of `unpack_scoped` is measured in the embedded stages of the total run, FT-E-05). Not specified: sibling `flags` members are separate scopes in C++, TypeScript and Java and one shared scope in Rust; and a group under `flags` whose only children are `flag_byte` and `flag_bit` is never present on pack in C++ (batch 1 discoveries 3 and 4, open owner questions).
**Max execution time**: 1s

### FT-X-16: Split-form bits are numbered by field order for each flag-byte read

**Summary**: TypeScript, C# and Java number split bits by field order per flag-byte read, as Rust and C++ do, and give the Rust bytes for the three probes; C++ packs the `k`/`a`/`b` rows below (AZ-2135 closed in loop 18 with AZ-2304).
**Traces to**: AZ-2135 AC-1, AZ-2135 AC-2, AZ-2135 AC-3
**Category**: Bytes

**Preconditions**:
- The packages as built in loops 16 and 17 (TypeScript, Java, C++ in loop 16; Python by AZ-2230; C# in loop 17)

**Input data**: three probes with one `flagByte` handle `m`: `[m, m.bit(u8 x)]` with `x = 5` in two schemes sharing the handle; `[m, early a, late b]` (`late` created first) with `b = 9`; `[m, m.bit(a), m, m.bit(b)]` with `b = 9`. C++: `u8 k, flag_byte(0), when(k == 1, [flag_byte(0), flag_bit(0, u8 a)]), flag_bit(0, u8 b)` with `{k: 0, b: 6}` and `{k: 1, a: 5, b: 6}`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the three probes in TypeScript, C# and Java (Rust is the reference) | `010105` (both schemes build), `010209`, `01000109` |
| 2 | pack the two C++ rows and unpack them | `01000106` and `010101010506`; both unpack; with no outer `flag_byte(0)` building fails with `SchemeInvalid` naming `b` |
| 3 | pack the golden, route and motion examples | unchanged |

**Expected outcome**: the bytes above in every package that has the probe; golden, route and motion unchanged.
**Max execution time**: 1s

### FT-X-17: C# refuses a collection member that cannot hold its field when the scheme is built

**Summary**: A C# typed row member whose element type cannot hold its field, or whose collection type is not supported, fails `new Scheme<T>` with `ArgumentException` naming the member (loop 18, AZ-2305).
**Traces to**: AZ-2305 AC-1, AZ-2305 AC-2, AZ-2305 AC-4
**Category**: Errors

**Preconditions**:
- C# as built in loop 18 (wave 1); net10.0 and netstandard2.0

**Input data**: `List<int>`, `int[]` and `Dictionary<string,int>` members for a `u32` list or dict field; `List<byte>` for a `u16` field; `Stack<int>`, `HashSet<int>`, `IEnumerable<int>` and a subclass of `List<E>` for a list field; a dictionary with `int` keys for a dict field; controls: `List<long>` for `u32`, every integer member that holds the field's whole range, `double` for `f32`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build each refused scheme | `ArgumentException` naming the member and the element type |
| 2 | build each control, then pack and unpack the existing suite schemes, the README example and the golden | the scheme builds; bytes and results unchanged |

**Expected outcome**: step 1 is an `ArgumentException` in every refused shape; step 2 is unchanged on net10.0 and netstandard2.0. The rule: an integer member must contain the field's whole range; `float`, `double` and `decimal` members are accepted; `IList<E>`, `IList`, `IDictionary<string,E>` and `IDictionary` are accepted; the check is skipped for list and dict fields inside a round. Not specified: whether `ICollection<E>` and `IReadOnlyList<E>` should be accepted (review C4, open owner question).
**Max execution time**: 1s

### FT-X-18: A non-null nested row with all members null is present

**Summary**: A non-null typed nested row object under a `Flags` group sets the group's bit even when every member is null, and pack then fails naming the first missing member; a null nested row stays absent (loop 18, AZ-2306).
**Traces to**: AZ-2306 AC-1, AZ-2306 AC-2, AZ-2306 AC-3
**Category**: Errors

**Preconditions**:
- C# as built in loop 18 (wave 1)

**Input data**: `Flags(0, Group(Leaf: u8 A, u8 B))` with `Leaf = new Leaf()` (all members null), `Leaf = null`; the depth-2 scheme `Flags(0, Group(Mid: u8 M, Group(Leaf: u8 A)))` with `Mid = new Mid()`, `Mid = {M=4, Leaf = new Leaf()}`, `Mid = {M=4, Leaf.A=6}`, `Mid = null`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the all-null objects (depth 1 and 2) | `ArgumentException` naming `A`, `M` and `A`; no bytes |
| 2 | pack the null nested rows | `0100`, the bit clear |
| 3 | pack the filled depth-2 row and unpack it | `01010406`; `Mid.Leaf.A` is 6 |

**Expected outcome**: step 1 is an `ArgumentException` naming the first missing member; step 2 is `0100` for both schemes; step 3 gives `01010406` and the same row.
**Max execution time**: 1s

### FT-X-19: A C# `Flags` list or dict element, and C# in the three element rings

**Summary**: A `Flags` container as a direct list or dict element packs and unpacks in C# with the TypeScript bytes, and C# takes part in the `listgroup`, `dictgroup` and `listflags` cross-language rings (loop 18, AZ-2307).
**Traces to**: AZ-2307 AC-1, AZ-2307 AC-2, AZ-2307 AC-3, AZ-2307 AC-4
**Category**: Bytes

**Preconditions**:
- C# as built in loop 18 (wave 1 and the ring files `.github/workflows/language-pair.sh`, `drivers/csharp/HandoffElements.cs`, `ring-wiring.test.sh`); the rings run in the one total test run (Docker or all six runtimes)

**Input data**: the element `flags{ u8 a (bit 0), u16 b (bit 1) }`; the list `[{a:1}, {}, {b:2}]`; the dict `{y: {b:2}, x: {a:1}}`; the ring hex `listgroup` `01020001020304`, `dictgroup` `01020001007801020100790304`, `listflags` `010300010100020200`, and their short forms `010200010203`, `010200010078010201007903`, `0103000101000202`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the list and the dict in C# dictionary mode and in typed mode | `010300010100020200` and `0102000100780101010079020200`, the TypeScript bytes; no `KeyNotFoundException` |
| 2 | unpack both hex strings | one row per element holding only what was read |
| 3 | `language-pair.sh` runs the rings (chain TypeScript, Python, Java, C#, TypeScript) | C# packs for and unpacks from its neighbour in each of the three rings, and refuses the three short packets |
| 4 | `ring-wiring.test.sh` with one C# handoff line, a driver command or the C# entry of the short-packet loop removed | the wiring test fails naming what is missing |

**Expected outcome**: step 1 gives the hex above; step 3 passes for `listgroup`, `dictgroup` and `listflags`; step 4 fails for each removal; the existing C# suite is unchanged on net10.0 and netstandard2.0. Not specified: the ring is a chain, not all pairs (review C10, open owner question: all pairs would add 18 handoffs).
**Max execution time**: 1s (steps 1, 2 and 4); the rings run in the CI ring job

### FT-X-20: C# `u2` slots, `bits` and `packed` items take whole numbers that fit

**Summary**: A C# `u2` slot, `bits` item or `packed` item accepts only a whole number that fits and refuses anything else with `ArgumentException` naming the member, as every other integer field does (loop 18, AZ-2309).
**Traces to**: AZ-2309 AC-1, AZ-2309 AC-2, AZ-2309 AC-3, AZ-2309 AC-4
**Category**: Errors

**Preconditions**:
- C# as built in loop 18 (wave 1)

**Input data**: `u2` of two slots; `u8 n` then `bits` (count n); `packed(1)` and `packed(2)` items; values: fractions (`1.5` in a `u2` slot, `2.5` and `0.5` in `bits`, `0.5` in `packed`); out of range (`4`, `-1`, `4.0` in `u2`; `2` in a `bits` or `packed(1)` item; `4` and `-1` in `packed(2)`; NaN, infinity); `true`, `"1"`, `'a'`, `DayOfWeek.Monday`, `new object()`, `null`; valid values `u2` 0, 3, 3.0, 2L, `(byte)1`, `bits` item 1 and 1.0, `packed(1)` item 1L, `packed(2)` item 3 and 3.0

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each fraction, each out-of-range value and each wrong-typed value | `ArgumentException` naming the member; no bytes |
| 2 | pack the valid values | `u2`: `0100`, `0103`, `0103`, `0102`, `0101`; `bits` item 1: `010202`; `packed(1)` item 1: `010202`; `packed(2)` item 3: `01020c` |
| 3 | pack a fraction inside `Flags`, a `Repeat` and a list element; pack the golden and route fixtures; run the 100000 round trips (NFT-PERF-01) | the fraction is refused; the fixtures and the timing are unchanged |

**Expected outcome**: step 1 is an `ArgumentException` in every case (a null item used to pack as 0 and is now refused); step 2 gives the hex above (a whole number held as `double` or `long` equals the integer bytes); step 3 as stated. Not specified: whether the other five packages round fractions in `u2` slots, `bits` and `packed` items (not probed; carried to the next loop, batch 1 discovery 13).
**Max execution time**: 1s

### FT-X-21: C# dictionary pack repacks what `Read` returned, and an int for `Bytes` or `Sized` is refused

**Summary**: The rows `Read` returns for a list or dict of group elements pack again to the original bytes, and an `int` given for a `Bytes` or `Sized` name is an `ArgumentException` naming the member, in and outside a round (loop 18, AZ-2310).
**Traces to**: AZ-2310 AC-1, AZ-2310 AC-2, AZ-2310 AC-3, AZ-2310 AC-4
**Category**: Bytes

**Preconditions**:
- C# as built in loop 18 (wave 1)

**Input data**: a list of group elements `u8 a, u8 b` (anchored and unanchored) and a dict of the same, with the packet `01 0200 0102 0304` (the `listgroup` ring packet) and its dict form; groups holding a string and flags; about 360 000 random packets over six schemes; the scheme `u8 n; bytes raw; sized data` with an `int` for `raw` and for `data`, outside a round and inside a `times` round

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | `Read` the packet in dictionary mode, pass the row to `Pack` | the original bytes `01020001020304`; no `'A' has no value` |
| 2 | unpack each random packet, then repack | the original packet (list schemes), or a stable second repack (dict schemes, whose keys are re-sorted); a packet that fails unpack fails in the same way |
| 3 | pack an `int` for a `Bytes` name and for a `Sized` name | `ArgumentException` naming the member; no `InvalidCastException` |
| 4 | pack `byte[]` for both; run the existing suite on both targets | the bytes of today; results unchanged |

**Expected outcome**: step 1 gives the original hex; step 2 holds for every random packet; step 3 is an `ArgumentException` in and outside a round; step 4 is unchanged on net10.0 and netstandard2.0.
**Max execution time**: 30s (the random repack)
