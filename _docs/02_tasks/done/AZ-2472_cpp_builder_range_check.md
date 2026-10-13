---
loop: 25
branch: dev
---

# C++ builder range check for every id

**Task**: AZ-2472_cpp_builder_range_check
**Name**: C++ builder range check on every id
**Description**: The C++ builder refuses every id that cannot fit a wire count: a count id of `times`/`bits`/`packed`/`sized` above 32 767, a field id above 32 767, and a `when` anchor above 32 767 all wrap; a count id of `-1` builds but then fails every pack and unpack with `BadValue`.
**Complexity**: 3 points
**Dependencies**: none
**Component**: cpp
**Tracker**: AZ-2472
**Epic**:

## Problem

The C++ builder accepts an id above the wire's 15-bit range for a count's field, a member's field or a `when` anchor; the id then wraps in the written bytes (e.g. `bits(1, 65536)` writes `bits(1, 0)` which binds field 0). A count id of `-1` builds but is a silent sentinel. The U25 A decision (handoff 25, D-batch 2026-10-14) names the fix: refuse at build time; the only hostile vector the audit allows through is the `-1` sentinel for a never-written count, which must build and then fail every pack/unpack with `BadValue`. The U19 pattern of early refusal applies.

Reference: `_docs/02_task_plans/round-parity-and-construction-checks/` (U25 row), AZ-2416 (U19 pattern), AZ-2431 (negative eq refused).

## Outcome

- The builder refuses, at `bind` / `times(...)` / `bits(...)` / `packed(...)` / `sized(...)` / `when(...)`, every id outside [0, 32767] except the sentinel `-1`, with an exception that names the member and the id.
- A count id of `-1` builds; the first pack or unpack after bind returns `BadValue` (`SchemeError::BadValue`) and names the field that reads from the never-written count.
- Zero regressions in `cpp/tests/` (host suite) and the arm embedded stage; flash and stack margins stay within the loop 24 figures (flash 40 B, stack 56 B).

## Scope

### Included

- `cpp/include/*` and `cpp/src/*` edits where the builder validates ids.
- New tests in `cpp/tests/` pinning every row in `## Blackbox Tests`.
- Owns (exclusive write): `cpp/include/**`, `cpp/src/**`, `cpp/tests/**`

### Excluded

- Any `python/`, `rust/`, `csharp/`, `java/`, `typescript/`, `go/` touch.
- Any `_docs/02_task_plans/**` wording changes (parent writes the row acceptance text at loop close).
- README edits (U24 is AZ-2479).

## Acceptance Criteria

**AC-1: Count id above 32 767 refused at build**
Given `bits(1, 65536)` or any count id of `times`/`bits`/`packed`/`sized` outside [0, 32767]
When the scheme builds
Then the builder throws a `SchemeError` naming the member and the id; the scheme is not built; packed bytes 0; unpacked values 0.

**AC-2: Field id above 32 767 refused at build**
Given a field id above 32 767 (e.g. `u8(65536, "x")`)
When the scheme builds
Then the builder throws a `SchemeError` naming the member and the id; the scheme is not built.

**AC-3: `when` anchor above 32 767 refused at build**
Given a `when(65536, ...)` anchor id
When the scheme builds
Then the builder throws a `SchemeError` naming the `when` and the anchor id; the scheme is not built.

**AC-4: Count id `-1` builds; pack and unpack return `BadValue`**
Given a count id of `-1` (never written) bound to a member
When the scheme builds
Then the scheme builds (0 exceptions at bind)
When any value is packed into or unpacked from a packet reading that member
Then every pack returns `BadValue` naming the member and the never-written count id; every unpack returns `BadValue` naming the same; written bytes 0; parsed values 0.

**AC-5: Embedded stage still fits**
Given the Cortex-M4F stage of `cpp/`
When linked with the AC-1 to AC-4 code added
Then flash ≤ 8192 B (margin ≥ 1 B at close; the loop 24 margin was 40 B) and stack ≤ 512 B (margin ≥ 1 B; loop 24 margin 56 B).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | `bits(1, 65536)`, `packed(1, 32768)`, `times(1, 70000)`, `sized(1, 65537)` build attempts | each throws naming the member and the id |
| AC-2 | `u8(65536, "x")`, `u16(70000, "y")` build attempts | each throws naming the member |
| AC-3 | `when(65536, Group(0, "g"), ...)` build attempt | throws naming the anchor id |
| AC-4 | count id `-1` `bits(-1, 2)`, then pack of a 2-bit value and unpack of a 1-byte packet | builds; pack returns `BadValue`; unpack returns `BadValue`; written bytes 0 |
| AC-5 | arm embedded link | flash ≤ 8192 B and stack ≤ 512 B after the AC-1 to AC-4 code |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `bits(1, 65536)` | build | `SchemeError` names member and id | |
| AC-2 | `u8(65536, "x")` | build | `SchemeError` names member and id | |
| AC-3 | `when(65536, Group(0, "g"), U8(0, "n"))` | build | `SchemeError` names anchor id | |
| AC-4 | `bits(-1, 2)` built, then pack `{member=3}` and unpack `01` | pack and unpack return `BadValue` naming the member | |
