---
loop: 39
branch: dev
---

# Message ECC review cleanups: dispatch order, distinct TooLong, Rust trait default

**Task**: AZ-2694_ecc_dispatch_toolong_alignment
**Name**: Message ECC review cleanups: dispatch order, distinct TooLong, Rust trait default
**Description**: Three behavior differences between packages found by the loop 38 review are aligned.
**Complexity**: 3 points
**Dependencies**: AZ-2690_ecc_docs
**Component**: all packages (ECC paths)
**Tracker**: AZ-2694
**Epic**: AZ-2677

## Problem

Loop 38 review (record38 leftovers, none blocking) found three places where one package differs from the contract's intent or from its peers:

1. The duplicate-type check runs before the receive index in Python and Java, after it in TypeScript, C# and Rust. The contract says a bad limit or a mix of counts is refused before the index advances, and says nothing about a duplicate type.
2. A buffer over 254 bytes is the rounds error in Go, Swift and C++; the other five packages have a distinct `TooLong`.
3. Rust `DispatchHandler` gained a required `parity()` method, which breaks outside implementors.

## Outcome

- One order in all eight packages: a duplicate type is refused before the receive index advances. The contract states it.
- Go, Swift and C++ report a buffer over 254 bytes with a distinct too-long error (name as the package's own style), not the rounds error.
- Rust `DispatchHandler::parity()` has a default, so an existing implementor still compiles.

## Scope

### Included
- Dispatch/duplicate-type check order in TypeScript, C#, Rust (and a test in all eight)
- Distinct too-long error in Go, Swift, C++ and its test
- Rust trait default and a test with an implementor that does not define `parity()`
- One sentence in `message-ecc.md`; a row in `results_report.md` only if a shared vector changes

### Excluded
- The parity setter shape (limits setter vs separate method): accepted as is
- Default correction limit and the 254-byte limit (owner decision, not this loop)
- Flash and stack: any `cpp/src/core` edit needs a measured saving first (`AGENT_GOTCHAS.md`, 60 B margin)

## Acceptance Criteria

**AC-1: duplicate type before the index**
Given a receiver with a duplicate type number in its handlers, and a payload
When unpack is called in any of the eight packages
Then the call is refused and the receive index is unchanged.

**AC-2: distinct too-long**
Given a buffer of 255 bytes or more with parity configured
When it is unpacked in Go, Swift or C++
Then the error is the too-long kind, not the rounds error, 0 values; the other five packages are unchanged.

**AC-3: Rust trait default**
Given a `DispatchHandler` implementor written against loop 37
When it is built with the current crate
Then it compiles, and its parity is 0.

**AC-4: no regression**
All shared vectors and the ring stay green; C++ flash 8,132 B and stack 492 B unchanged on the arm stage.

## Constraints

- Disjoint package folders: one worker per package, the parent keeps commits and the contract sentence.
- Host recipes: `AGENT_GOTCHAS.md` (Go in `golang:1.27`, Swift flags, `MSBUILDDISABLENODEREUSE=1`, GCC 16 check for C++).
