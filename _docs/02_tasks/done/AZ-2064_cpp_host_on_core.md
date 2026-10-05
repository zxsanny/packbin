---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ host programs on the core; dynamic walker removed

**Task**: AZ-2064_cpp_host_on_core
**Name**: C++ host on core
**Description**: The host suite, compile-fail check, language-pair drivers and benchmark use the core API, and the dynamic walker and its API are deleted.
**Complexity**: 5 points
**Dependencies**: AZ-2062_cpp_core_grouped_kinds, AZ-2063_cpp_core_counted_kinds, AZ-2065_cpp_core_session
**Component**: cpp
**Tracker**: AZ-2064
**Epic**: AZ-2059

## Problem

Decision D-2 B moves host programs to the core API. Until the old API and walker are gone, the tree has two implementations of every field rule.

## Outcome

- One walker in `cpp/`. `BinaryPacker`, `Scheme<T>` with `std::function` bindings, `Value`/`Values` and the exception error path are removed.
- Every hex vector the host suite asserted before the port is still asserted, in one vector table that the host tests and the firmware runner (AZ-2066) both read.
- README C++ section shows the core API and has a migration list from 0.1.x.

## Scope

### Included
- Port `cpp/tests/*.cpp`, `cpp/tests/compile-fail`, `.github/workflows/drivers/handoff.cpp` and `position.cpp`, and the throughput check to the core API.
- Delete the dynamic walker sources and headers; update `cpp/Makefile`, `language-pair.sh` and the vcpkg copy list in `publish-registries.sh` for the new file set.
- README C++ section and migration list (every removed or renamed public symbol → replacement).

### Excluded
- Session port (AZ-2065), embedded packaging (AZ-2067), other languages.

## Acceptance Criteria

**AC-1: Host suite green on the core**
Given the ported host suite and compile-fail check
When `make test` runs in `cpp/`
Then failures are 0 and the count of asserted vectors is ≥ the count before the port (vectors dropped: 0).

**AC-2: Language pairs unchanged**
Given `language-pair.sh` with the ported C++ drivers
When it runs `user`, `nested`, `session` and position pairs
Then every pair involving C++ passes with the same hex as before.

**AC-3: One walker**
Given the tree after the port
When it is searched for the old dynamic API (`BinaryPacker`, `Values`, `std::function` bindings, `throw`)
Then references in `cpp/` and the C++ drivers are 0.

**AC-4: Host speed holds**
Given 100000 round trips of the position row on one core
When the throughput check runs on the host
Then it finishes in ≤ 1 second (project AC-10).

**AC-5: Upgrade path documented**
Given the 0.1.x public header
When each public symbol is compared to the README C++ migration list
Then every removed or renamed symbol has a row naming its replacement (S10; feature AC-11).

## Non-Functional Requirements

**Performance**
- AC-10 project throughput.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | full host suite | 0 failures, vectors ≥ before |
| AC-3 | grep for old API in `cpp/` and drivers | 0 hits |
| AC-4 | 100000 round trips | ≤ 1 s |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | test compose, all six languages | language pairs with C++ | all pass | — |
| AC-5 | 0.1.x header symbol list | README migration list | one row per removed/renamed symbol | — |

## Constraints

- Decision D-1 A and D-2 B (fit card 3): one walker; breaking C++ release.
- Other languages and wire bytes do not change.
- Record the vector count before the port in the batch report so AC-1 can be checked.

## Risks & Mitigation

**Risk 1: Vectors lost in the port**
- *Risk*: a test rewrite silently drops an assertion.
- *Mitigation*: count asserted hex vectors before and after; the batch report states both numbers.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Breaking C++ release for host users | D-2 B, user 2026-10-04 | accepted-risk | Medium |
