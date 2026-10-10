---
loop: 18
branch: dev
---

# C# supports a Flags container as list or dict element and joins the group and flags rings

**Task**: AZ-2307_csharp_flags_element_and_rings
**Name**: C# flags element and ring wiring
**Description**: A `Flags` container as a direct list or dict element packs and unpacks in C# with the same bytes as TypeScript, Python and Java, and C# takes part in the `listgroup`, `dictgroup` and `listflags` cross-language rings.
**Complexity**: 3 points
**Dependencies**: AZ-2119_csharp_group_list_element (done), AZ-2239_listgroup_cross_language_ring (done)
**Component**: csharp, shared harness (`.github/workflows/drivers/csharp/`, `language-pair.sh`, `ring-wiring.test.sh`)
**Tracker**: AZ-2307
**Epic**: AZ-2069

## Problem

Owner decision 5 of loop 18 (2026-10-10, option A; assessment E4) and the ring gap of AZ-2119 AC-1.

- A `Flags` container as a direct list or dict element throws `KeyNotFoundException` in C# `Read`; TypeScript, Python, Java and the ring `listflags` accept it.
- Loop 17 checked the C# unpacked shape of group elements by reading the other drivers, not by running them: C# has no case in the `listgroup` and `dictgroup` rings.

## Outcome

- The same scheme gives the same bytes and the same unpacked shape in C# as in the other packages, for flags elements in lists and dicts, typed and dictionary mode.
- The rings prove it on every CI run.

## Scope

### Included
- C# walker and typed binding for a `Flags` element; the C# driver case and handoff lines for the three rings; `ring-wiring.test.sh` updated.

### Excluded
- Other packages' code (they already accept it); new ring shapes beyond the three.

## Acceptance Criteria

**AC-1: flags element in a list and a dict packs and unpacks**
Given a list and a dict whose element is a `Flags` container (the `listflags` ring shape)
When packed and unpacked in C# dictionary mode and typed mode
Then no `KeyNotFoundException`; the bytes equal the TypeScript bytes for the same scheme and row, and the unpacked shape matches

**AC-2: listgroup and dictgroup rings include C#**
Given the C# driver
When `language-pair.sh` runs the `listgroup` and `dictgroup` rings
Then C# packs for and unpacks from every other package, and the ring wiring test fails if a handoff line is missing

**AC-3: listflags ring includes C#**
Given the C# driver
When the `listflags` ring runs
Then C# is a member in both directions

**AC-4: existing behavior unchanged**
Given golden, route, the existing C# suite on net10.0 and netstandard2.0
When run
Then results are unchanged

## Non-Functional Requirements

**Compatibility**
- No wire change for schemes that work today.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | list and dict of `Flags` elements, both modes | TypeScript bytes; same shape |
| AC-4 | existing suite | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | `language-pair.sh` with Docker or local runtimes as the CI does | the three rings | green with C# included | — |
| AC-3 | same | `listflags` | green with C# included | — |

## Constraints

- ADR-001: C# implements it itself. Shared harness files are edited by one worker only. Files stay at or under 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ring run needs Docker or all six runtimes; the loop's one total test run executes it, not the worker | owner preference (one total test run) | accepted-risk | Low |

## Loop 18 result (2026-10-10)

Done in loop 18 wave 1 (csharp and ring files). A `Flags` list or dict element packs and unpacks in dictionary and typed mode; bytes from a TypeScript run: list `[{a:1},{},{b:2}]` `010300010100020200`, dict `{y:{b:2}, x:{a:1}}` `0102000100780101010079020200`. C# is a member of the `listgroup`, `dictgroup` and `listflags` rings (chain typescript, python, java, csharp, typescript; driver `drivers/csharp/HandoffElements.cs`, `ring-wiring.test.sh` checks six C# lines). The rings run in step 11. The C# handoff driver `NestedScheme` was fixed (it used one member as list and dict).
