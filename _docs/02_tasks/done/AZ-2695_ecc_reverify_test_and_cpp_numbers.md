---
loop: 39
branch: dev
---

# Message ECC review cleanups: re-verify test and C++ description numbers

**Task**: AZ-2695_ecc_reverify_test_and_cpp_numbers
**Name**: Message ECC review cleanups: re-verify test and C++ description numbers
**Description**: The post-repair re-verify has a second test, and the C++ component description carries the measured ECC-build numbers.
**Complexity**: 2 points
**Dependencies**: AZ-2690_ecc_docs
**Component**: all packages (tests), cpp (docs)
**Tracker**: AZ-2695
**Epic**: AZ-2677

## Problem

A mutation run showed the post-repair re-verify (the check that the repaired buffer is a valid codeword) is covered by one test only. The C++ component description still says 456 of 512 B and 8152 of 8192 B on lines 130 and 163 to 182.

## Outcome

- A second test fails when the re-verify is removed (mutation run confirms it), in the packages where one test covered it.
- The C++ description states the measured numbers of the ECC builds, with the measuring command.

## Scope

### Included
- A test for the re-verify with a mutant run (remove the re-verify, the test fails)
- `_docs/02_document/components/` C++ description lines 130 and 163 to 182

### Excluded
- Any source change in `cpp/src/core` (flash margin 60 B)

## Acceptance Criteria

**AC-1: re-verify has two tests**
Given the re-verify removed in a package (mutant)
When that package's test suite runs
Then at least two tests fail.

**AC-2: C++ numbers**
Given the C++ component description
When it is read
Then every flash and stack number matches the last arm stage run (8,132 B flash and 492 B stack on Cortex-M4F; M0+, M3 and ESP32 pass or fail only), and no present-tense statement of 456 or 8152 remains (dated 'Loop N changes' history entries keep the numbers of their day).

## Constraints

- The mutant is run on a scratch copy of the tree, never in the shared checkout (`AGENT_GOTCHAS.md`: no git stash, checkout, reset).
- Docs numbers come from a run, not from the record.
