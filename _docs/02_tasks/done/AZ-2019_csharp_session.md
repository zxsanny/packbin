---
loop: 9
branch: loop/9-pack-session
---

# C# connection session

**Task**: AZ-2019_csharp_session
**Name**: C# connection session
**Description**: C# loads a 32-byte seed, the opener produces 16 bytes, the waiter joins, and a position row round-trips at the clear packed length.
**Complexity**: 5 points
**Dependencies**: None
**Component**: csharp
**Tracker**: AZ-2019
**Epic**: AZ-2018

## Problem

Callers can pack a field list, and those bytes are visible on the connection. They need one session per connection, and they still need the clear pack.

## Outcome

- A 32-byte seed loads. Any other length creates 0 sessions.
- Start returns 16 bytes. Join of those bytes opens the waiter.
- The position row round-trips in both directions. Payload length is 13. Added bytes: 0.
- A second packet on that connection round-trips.
- A second session with a different 16-byte value does not return the original row.
- Pack before start or join produces 0 payloads.
- Clear pack of the position row remains `4001000065cd1d00a3e1110100`.

## Scope

### Included

- The C# session on the public entry.
- Tests for S1–S8.

### Excluded

- The other five languages.
- The README.
- Opening a socket.
- A flipped-bit check.

## Acceptance Criteria

**AC-1: Clear pack is unchanged.**
Given the position row.
When packed with the existing packer.
Then the bytes are `4001000065cd1d00a3e1110100`. Mismatched bytes: 0.

**AC-2: The opener and the waiter round-trip.**
Given a 32-byte seed and the opener's 16 bytes.
When the opener packs the position row and the waiter unpacks it.
Then field mismatches: 0. Payload length: 13.

**AC-3: The waiter sends.**
Given that connection.
When the waiter packs and the opener unpacks.
Then field mismatches: 0.

**AC-4: A second packet round-trips.**
Given one packet already unpacked.
When a second row is packed and unpacked.
Then field mismatches: 0.

**AC-5: Two sessions stay apart.**
Given two 16-byte values and one seed.
When A's payload is unpacked on B.
Then the original row is not returned. Original rows: 0.

**AC-6: Bad lengths create nothing.**
Given a seed length other than 32, or a join length other than 16.
When the caller loads or joins.
Then sessions created: 0.

**AC-7: Pack before open fails.**
Given a loaded seed and no start and no join.
When the caller packs.
Then payloads produced: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | clear position pack | golden hex, 0 mismatched bytes |
| AC-2 | opener pack, waiter unpack | 0 field mismatches, length 13 |
| AC-3 | waiter pack, opener unpack | 0 field mismatches |
| AC-4 | second packet | 0 field mismatches |
| AC-5 | two sessions | 0 original rows |
| AC-6 | bad lengths | 0 sessions |
| AC-7 | pack before open | 0 payloads |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | position row | clear pack | golden hex | project AC-1 |

## Constraints

- The six packages stay peers. C# does not become a library the others import.
- The caller stores the seed and sends the 16 bytes.

## Risks & Mitigation

**Risk 1: Clear bytes drift**
- *Risk*: The session work changes the golden hex.
- *Mitigation*: AC-1 fails the task if the clear hex changes.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| One shared seed decrypts every client | Caller | accepted-risk | High |
| A flipped bit is not detected | Caller | accepted-risk | High |
| A dropped packet desynchronizes the session | Caller | accepted-risk | Medium |

## Contract

This task produces the contract at `_docs/02_document/contracts/library/pack-session.md`.
Consumers read that file.
