---
loop: 25
branch: dev
---

# README note: C++ clear bit for an unbound member behind a clear `when`

**Task**: AZ-2479_readme_cpp_clear_bit_unbound
**Name**: README note: C++ clear bit for an unbound member behind a clear `when`
**Description**: U24 B (handoff 25): C++ packs the clear bit for an unbound `bits`/`packed`/`sized` member (no member pointer) whose count sits behind a clear `when`; an unbound member is C++'s "not carried" spelling. The README's data-type and "no value" wording picks that up so users do not reach for a null pointer in a language without one.
**Complexity**: 1 point
**Dependencies**: none
**Component**: docs (README only)
**Tracker**: AZ-2479
**Epic**:

## Problem

C++ has no nullable member pointer. The project's seven-language "no value" story has to spell C++'s equivalent: a member that is not bound to a pointer or variable. The behavior exists already; U24 B names it and the README needs the one paragraph so the row reads the same across languages.

Reference: `README.md` ("Untrusted input" / "Limits to keep in mind" / data-type notes), `_docs/02_task_plans/round-parity-and-construction-checks/` (U24 row).

## Outcome

- README has one short paragraph (one sentence or two) in the C++ section (or the no-value wording that spans the seven) naming "unbound" as C++'s "not carried" spelling, with the example: a `bits`/`packed`/`sized` member whose count sits behind a clear `when`, left unbound, packs the clear bit.
- No code change; this is a wording-only ticket.
- The data-type table marks C++ as covering the no-value row (if the table does not already).

## Scope

### Included

- `README.md` only.
- Owns (exclusive write): `README.md` paragraph for the C++ no-value row.

### Excluded

- Any source change.
- Any other README section.
- Any `_docs/02_task_plans/**` change (parent writes the parity row text at close if needed).

## Acceptance Criteria

**AC-1: README names C++'s unbound spelling**
Given the README's no-value wording
When read
Then C++ is named with "unbound" (or the project's exact word) as the "not carried" spelling, with one example.

**AC-2: Data-type table marks C++**
Given the README data-type table
When read
Then the no-value row has a tick (or whatever marker the table uses) for C++.

**AC-3: Build and tests unchanged**
Given the README edit
When CI runs
Then the build and every test pass as before; new failures 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | README grep for the paragraph | one match |
| AC-2 | README data-type row | C++ marked |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | the README | grep | paragraph present | |
