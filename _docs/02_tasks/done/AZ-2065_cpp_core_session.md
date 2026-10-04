---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ core: session on caller buffers

**Task**: AZ-2065_cpp_core_session
**Name**: C++ core session
**Description**: `PackSession` works on caller buffers with a caller random function; the OS random source lives in one host-only adapter.
**Complexity**: 2 points
**Dependencies**: AZ-2061_cpp_core_schemes
**Component**: cpp
**Tracker**: AZ-2065
**Epic**: AZ-2059

## Problem

`PackSession` includes `<sys/random.h>`, reads `/dev/urandom` and returns `std::vector`, so it cannot build for a board (`problem.md` blocker 7).

## Outcome

- Session `start`, `join`, `pack` and `unpack` run on caller buffers with in-place XOR; 0 heap calls.
- The random source is a caller function `bool(*)(uint8_t* out, size_t n, void* ctx)`.
- The host build provides an OS random adapter in one file that firmware does not compile.

## Scope

### Included
- Session on the core; host OS random adapter; port of `cpp/tests/session_tests.cpp` to the new API with every vector kept.

### Excluded
- Other languages' sessions; QEMU proof (AZ-2066).

## Acceptance Criteria

**AC-1: Same session bytes**
Given a 32-byte seed, a fixed nonce and the `pack-session` cross-language vectors
When the core session runs `start`, `join`, `pack` and `unpack`
Then padded bytes equal the vectors in every byte, and clear pack stays `4001000065cd1d00a3e1110100` (feature AC-10).

**AC-2: Random failure**
Given a random function that reports failure
When `start` runs without a caller nonce
Then it returns an error and 0 bytes are padded (S8).

**AC-3: No OS in the core**
Given the core sources
When they are searched and compiled without POSIX headers
Then `<sys/random.h>`, `/dev/urandom` and `arc4random` appear only in the host adapter file.

**AC-4: Length rules kept**
Given a seed length other than 32 or a nonce length other than 16
When `load`, `start` or `join` runs
Then 0 sessions are created or joined, as today.

## Non-Functional Requirements

**Compatibility**
- Same core profile as AZ-2060; HKDF/SHA-256 stays in-house.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | session vectors | byte-identical |
| AC-2 | failing random function | error, 0 padded bytes |
| AC-3 | grep core sources | 0 OS random references outside the adapter |
| AC-4 | wrong seed/nonce lengths | 0 sessions |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `language-pair.sh` session pair | C++ ↔ C# session | pass | — |

## Constraints

- `pack-session` criteria stay in force.
- D-2 B: the session API changes to the core shape; listed in the README migration list (AZ-2064).

## Risks & Mitigation

**Risk 1: Counter state on the caller side**
- *Risk*: in-place XOR on a caller buffer must not change the packet index rules.
- *Mitigation*: the existing session vectors cover packet indices; none dropped.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
