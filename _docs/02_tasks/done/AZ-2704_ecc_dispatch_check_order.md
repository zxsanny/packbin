---
loop: 40
branch: dev
---

# Message ECC: one check order for dispatch calls, required Rust parity()

**Task**: AZ-2704_ecc_dispatch_check_order
**Name**: Message ECC: one check order for dispatch calls, required Rust parity()
**Description**: The checks an unpack call runs before it reads a byte follow one order in all eight packages, and none spends a receive position.
**Complexity**: 3 points
**Dependencies**: AZ-2694_ecc_dispatch_toolong_alignment
**Component**: all packages (dispatch and session receive)
**Tracker**: AZ-2704
**Epic**: AZ-2677

## Problem

The loop 39 total review (record39 leftovers, 4 Lows, none blocking) found that the argument checks of a dispatch call run in different orders, so one bad call gets a different error, or spends a receive position, depending on the package. A survey of all eight packages at `75b1d39`:

| Package | Session: not open before duplicate | Empty list refused before a position | Duplicate before parity mix and limit |
|---------|------------------------------------|--------------------------------------|---------------------------------------|
| Python | yes | yes (`TypeError`) | one loop, per handler (no) |
| TypeScript | no | cannot happen (`first` is required) | yes |
| C# | no | no | yes |
| Java | yes | no | no |
| Rust | yes | no | no (parity, limit, then duplicate) |
| Go | yes | yes | yes |
| Swift | yes | no | session yes, `BinaryPacker` no |
| C++ | yes | cannot happen (`first` is required) | yes |

The Rust `DispatchHandler::parity()` defaults to 0 (loop 39, AZ-2694 AC-3), so a hand-written handler of a scheme with parity bytes gets no repair and no compile error. The owner chose a required method (2026-10-19): no tag exists, so the break costs nothing.

## Outcome

- One order, Go's, in every package and on every entry point (packer and session): (1) a session that is not open returns its short result (needed 1, left 0); (2) an empty handler list is refused; (3) a duplicate type number is refused; (4) handlers with different parity counts are refused; (5) a correction limit outside 0..n/2 is refused. Only then is a receive position spent.
- Rust `DispatchHandler::parity()` has no default.
- `message-ecc.md` states the order in the Dispatch row.

## Scope

### Included
- TypeScript session: the duplicate check moves after the not-open check
- C# session: the same; an empty handler list throws `ArgumentException` on the packer and the session before a position
- Java: the duplicate check moves before `Ecc.sharedParity` (packer and session); an empty handler list throws `IllegalArgumentException` before a position
- Python: `_dispatch_table` refuses duplicates in a first pass, then compares parity counts
- Rust: `check_unique` runs before `shared_parity` and `check_limit` (packer and session); a new `UnpackError::NoHandlers` for an empty list, refused before a position; `parity()` required, the loop 37 compatibility test removed or rewritten
- Swift: one `checkSchemes` (empty, then duplicate) runs before `Ecc.sharedParity` on the packer and the session
- One test per package for each changed rule; one sentence in `message-ecc.md`

### Excluded
- Go and C++ code (already in this order); a test is added in Go only if a rule has none
- The default correction limit (0) and the 254-byte limit: kept (owner 2026-10-19)
- Error names and kinds: every package keeps its own refusal type; only the order changes, plus the one new Rust variant
- `cpp/src/core`: untouched (flash margin 60 B)

## Acceptance Criteria

**AC-1: not open first**
Given a session that is not open and a handler list with a duplicate type number
When a payload is unpacked in TypeScript or C#
Then the result is the not-open short result (needed 1, left 0), as in the other six packages.

**AC-2: empty list spends no position**
Given an open session and an empty handler list
When a payload is unpacked in C#, Java, Rust or Swift
Then the call is refused and the receive index is unchanged: the next payload from the sender is read at its own index.

**AC-3: duplicate before parity mix and limit**
Given handlers with a duplicate type number and different parity counts (or a limit above n/2)
When a payload is unpacked in Python, Java, Rust or Swift (packer and session)
Then the refusal is the duplicate-type one, as in Go, TypeScript, C# and C++.

**AC-4: Rust parity() required**
Given a `DispatchHandler` implementor without `parity()`
When it is built against the crate
Then it does not compile; the `On` implementor and every test handler define it.

**AC-5: no regression**
All shared vectors, the 64-pair ECC ring and every package suite stay green.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | not-open session, duplicate handlers (TypeScript, C#) | short result, needed 1, left 0 |
| AC-2 | empty list then a valid payload (C#, Java, Rust, Swift) | refusal, then the valid payload unpacks at its index |
| AC-3 | duplicate + mixed parity; duplicate + bad limit (Python, Java, Rust, Swift) | duplicate-type refusal |
| AC-4 | Rust compile-fail or trait docs; `On` keeps parity | handler without `parity()` does not compile |

## Constraints

- Host recipes: `AGENT_GOTCHAS.md` (Swift test flags, `MSBUILDDISABLENODEREUSE=1`, Go in `golang:1.27`).
- One total review and one step 11 run for the loop.
