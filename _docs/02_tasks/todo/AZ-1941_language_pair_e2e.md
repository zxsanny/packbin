---
loop: 2
branch: loop/2-strings-lists-dicts
---

# Language-pair end to end

**Task**: AZ-1941_language_pair_e2e
**Name**: Language-pair end to end
**Description**: One language packs a nested value and another language unpacks those exact bytes.
**Complexity**: 5 points
**Dependencies**: AZ-1940_dictionary
**Component**: library
**Tracker**: AZ-1941
**Epic**: AZ-1937

## Problem

Each language matching a fixture still allows two neighbors to disagree on a nested map. A length that is off by one byte only shows up when the next language reads the buffer.

## Outcome

- These six handoffs each unpack to the same fields the producer packed, with 0 wrong fields and 0 bytes left:
  - C# packs, TypeScript unpacks
  - TypeScript packs, Python unpacks
  - Python packs, Rust unpacks
  - Rust packs, Java unpacks
  - Java packs, C++ unpacks
  - C++ packs, C# unpacks
- Each handoff carries two values: the 103-byte user value from AZ-1940, and a dictionary of string to list of dictionaries of string to string whose pack is 58 bytes `020003006d61700100010002006f7007006770735f666978050073746f72650200010002006f70040072656164010002006f7005007772697465` (`map` → one entry `op`=`gps_fix`; `store` → `op`=`read` and `op`=`write`).
- The position record still packs to 13 bytes `4001000065cd1d00a3e1110100` in each language. Mismatched bytes: 0.

## Scope

### Included

- The six handoffs above
- The user value and the nested dictionary
- The existing position record

### Excluded

- A seventh language
- A registry publish
- A stub in place of `pack` or `unpack`

## System Under Test Boundary

Real `pack` in the producer language and real `unpack` in the consumer language. The bytes between them are the only input. No stand-in result.

## Acceptance Criteria

**AC-1: User value across a handoff**
Given the 103-byte user value
When each of the six handoffs packs and then unpacks
Then wrong fields are 0 and bytes left are 0

**AC-2: Nested dictionary across a handoff**
Given `map` → [`op`=`gps_fix`] and `store` → [`op`=`read`, `op`=`write`]
When each of the six handoffs packs and then unpacks
Then the bytes are the 58-byte hex in Outcome, wrong fields are 0, and bytes left are 0

**AC-3: Position record unchanged**
Given type 64, sid 1, latitude 500000000, longitude 300000000, profile 1, and motion flags clear
When each language packs it
Then the bytes are `4001000065cd1d00a3e1110100` and mismatched bytes are 0

## Non-Functional Requirements

**Compatibility**
- Every handoff mismatches on 0 bytes against the hex for that value

**Reliability**
- Bytes left after unpack are 0. A length that overshoots fails AC-1 or AC-2.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | one handoff of the nested dictionary | 58-byte hex, bytes left 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | user value | all six handoffs | wrong fields 0, bytes left 0 | Compatibility, Reliability |
| AC-2 | nested `map` / `store` dictionary | all six handoffs | 58-byte hex, wrong fields 0, bytes left 0 | Compatibility, Reliability |
| AC-3 | position fixture | pack in each language | 13 bytes `4001000065cd1d00a3e1110100` | — |

## Constraints

- The consumer uses the same field list as the producer.
- No registry call.

## Risks & Mitigation

**Risk 1: Only a shared fixture is compared**
- *Risk*: two languages can both miss the fixture in the same way
- *Mitigation*: AC-1 and AC-2 require the producer bytes to be what the consumer reads

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |

## Scenarios

S7.
