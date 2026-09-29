---
loop: 9
branch: loop/9-pack-session
---

# Java connection session

**Task**: AZ-2024_java_session
**Name**: Java connection session
**Description**: Java matches the C# session for one seed, one 16-byte value, and the position row.
**Complexity**: 3 points
**Dependencies**: AZ-2019_csharp_session
**Component**: java
**Tracker**: AZ-2024
**Epic**: AZ-2018

## Problem

Java can pack the position row in the clear. A peer that opened a session in C# must be able to read a Java payload, and Java must read a C# payload.

## Outcome

- The same 32-byte seed and 16-byte value as C# produce the same 13-byte payload. Mismatched bytes: 0.
- A waiter unpacks that payload to the five position fields. Field mismatches: 0.
- Clear pack remains `4001000065cd1d00a3e1110100`.
- A seed length other than 32, or a join length other than 16, creates 0 sessions.

## Scope

### Included

- The Java session on that package's public entry.
- A test against the C# ciphertext for the position row.

### Excluded

- The other languages' implementations.
- The README.
- A flipped-bit check.

## Acceptance Criteria

**AC-1: The ciphertext matches C#.**
Given the position row, the C# 32-byte seed, and the C# 16-byte opener value.
When Java packs on the opener.
Then the bytes equal the C# payload. Mismatched bytes: 0. Length: 13.

**AC-2: The waiter recovers the row.**
Given that payload.
When a Java waiter unpacks it.
Then field mismatches: 0.

**AC-3: Clear pack is unchanged.**
Given the position row.
When packed with the existing packer.
Then the bytes are `4001000065cd1d00a3e1110100`. Mismatched bytes: 0.

**AC-4: Bad lengths create nothing.**
Given a seed length other than 32, or a join length other than 16.
When the caller loads or joins.
Then sessions created: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | opener pack | 0 mismatched bytes against C# |
| AC-2 | waiter unpack | 0 field mismatches |
| AC-3 | clear pack | golden hex |
| AC-4 | bad lengths | 0 sessions |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | C# fixture | Java pack | same 13 bytes | project AC-3 |

## Constraints

- This package imports no other packbin package.
- Document dependency: `_docs/02_document/contracts/library/pack-session.md`
- If a source file is added, every driver compile line that must see it is updated, including the publish gate.

## Risks & Mitigation

**Risk 1: A prefix match hides a different tail**
- *Risk*: The payload looks right and differs at the end.
- *Mitigation*: AC-1 compares the full hex.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| One shared seed decrypts every client | Caller | accepted-risk | High |
| A flipped bit is not detected | Caller | accepted-risk | High |
