---
loop: 9
branch: loop/9-pack-session
---

# README shows clear pack and the session

**Task**: AZ-2026_readme_session
**Name**: README shows clear pack and the session
**Description**: The README keeps the clear pack example and adds one session example with a single 16-byte send.
**Complexity**: 2 points
**Dependencies**: AZ-2019_csharp_session
**Component**: library
**Tracker**: AZ-2026
**Epic**: AZ-2018

## Problem

A reader of the README can see only clear pack. The session has to be visible next to it, including that the 16 bytes are sent once per connection.

## Outcome

- The existing clear pack example remains.
- One session example shows load, start, the 16-byte send, pack, and the waiter joining and unpacking.
- The example states that a second client is a second session.

## Scope

### Included

- The README only.

### Excluded

- Changing pack or the session behavior.
- Archangel's socket code.

## Acceptance Criteria

**AC-1: Both examples are in the README.**
Given the README.
When a reader looks at the examples.
Then clear pack examples: at least 1. Session examples: 1. The session example includes one 16-byte send and no second handshake.

**AC-2: The session example matches the contract.**
Given the contract operations load, start, join, pack, and unpack.
When compared to the README session example.
Then each of those five operations appears once in that example. Missing operations: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | README text | 1 session example, clear example kept |
| AC-2 | operations named | 0 missing operations |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | README | a reader | both ways shown | — |

## Constraints

- Document dependency: `_docs/02_document/contracts/library/pack-session.md`
- Do not remove the clear golden hex from the README.

## Risks & Mitigation

**Risk 1: The clear example is replaced**
- *Risk*: A reader can no longer see pack without a session.
- *Mitigation*: AC-1 requires the clear example to remain.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| One shared seed decrypts every client | Caller | accepted-risk | High |
| A flipped bit is not detected | Caller | accepted-risk | High |
