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
