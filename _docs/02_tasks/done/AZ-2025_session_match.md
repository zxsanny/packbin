---
loop: 9
branch: loop/9-pack-session
---

# Six languages agree on one session packet

**Task**: AZ-2025_session_match
**Name**: Six languages agree on one session packet
**Description**: The same seed, nonce, and position row produce one ciphertext in all six languages, and a peer recovers the row.
**Complexity**: 3 points
**Dependencies**: AZ-2019_csharp_session, AZ-2020_typescript_session, AZ-2021_python_session, AZ-2022_rust_session, AZ-2023_cpp_session, AZ-2024_java_session
**Component**: library
**Tracker**: AZ-2025
**Epic**: AZ-2018

## Problem

Each language can round-trip alone and still disagree on the bytes a peer must read.

## Outcome

- For one fixed 32-byte seed, one fixed 16-byte value, and the position row, all six ciphertexts are identical. Mismatched bytes: 0.
- A waiter in a second language recovers the five fields. Field mismatches: 0.
- The clear golden hex is still `4001000065cd1d00a3e1110100` in every language.

## Scope

### Included

- One shared fixture and a check that all six match it.
- A cross-language unpack of that fixture.

### Excluded

- New session behavior beyond the contract.
- Archangel.

## Acceptance Criteria

**AC-1: One ciphertext.**
Given the position row, one 32-byte seed, and one 16-byte opener value.
When each language's opener packs it.
Then all six outputs are equal. Mismatched bytes: 0. Length: 13.

**AC-2: A peer unpacks it.**
Given that ciphertext and a waiter in another language.
When the waiter unpacks it.
Then field mismatches: 0.

**AC-3: Clear pack still matches.**
Given the position row packed clear in each language.
When compared to `4001000065cd1d00a3e1110100`.
Then mismatched bytes: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | six ciphertexts | 0 mismatched bytes |
| AC-2 | cross-language unpack | 0 field mismatches |
| AC-3 | clear golden hex | 0 mismatched bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | fixed seed, nonce, position row | six packs | one hex | project AC-3 |

## Constraints

- Compare the full hex. A shared prefix is not a match.
- Document dependencies: `_docs/02_document/contracts/library/pack-session.md`

## Risks & Mitigation

**Risk 1: A prefix match hides a different tail**
- *Risk*: Two languages look alike and differ at the end.
- *Mitigation*: AC-1 compares the full hex.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| One shared seed decrypts every client | Caller | accepted-risk | High |
| A flipped bit is not detected | Caller | accepted-risk | High |
