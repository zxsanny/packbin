# Blackbox Tests 5: Sessions

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

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

