# Blackbox Tests 4: Borrowed counts and field order

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

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

