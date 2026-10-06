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
**Traces to**: AZ-2070 AC-1, AZ-2070 AC-2, AZ-2070 AC-3, AZ-2070 AC-4
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: `fixtures/hostile/cases.txt`, nine corrupted copies of it and a README copy without one section

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run `fixtures/hostile/cases.test.sh` (the `scaffold` job runs it) | 19 ids pass; each corrupted copy exits non-zero and names its line; every id has a README section |

**Expected outcome**: 19 ids pass; each corrupted copy exits non-zero and names its line; every id has a README section.
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
**Traces to**: AZ-2078 AC-4
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: the 17 `unpack` and `construct` cases of the 19 in `fixtures/hostile/cases.txt` (the 2 `limit` cases are skipped: C++ has no round limit, AZ-2220)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | the host runner builds each scheme by hand and unpacks or validates it | each outcome is one the file allows; each case within 1 s; bytes written outside the row 0 |

**Expected outcome**: each outcome is one the file allows; each case within 1 s; bytes written outside the row 0.
**Max execution time**: 17s

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
