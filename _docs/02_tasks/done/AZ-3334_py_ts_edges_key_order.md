---
loop: 76
branch: dev
---

# Python and TypeScript `edges` probes pass NFD before NFC, so their info line is true

**Task**: AZ-3334_py_ts_edges_key_order
**Name**: Python and TypeScript edges probes: NFD key first
**Description**: The NFC/NFD case of the two information probes uses ascending key order, so the packet is accepted and the printed text is true.
**Complexity**: 1 point
**Dependencies**: AZ-3329_probe_fixes
**Component**: hostile fuzz probes (`fixtures/hostile/fuzz/`)
**Tracker**: AZ-3334
**Epic**: AZ-2645

Feature assessment loop 76 round 1, new angle A1 (CLARIFY). Owner, 2026-10-27: "Swap the keys in both (Recommended)".

## Problem

`fixtures/hostile/fuzz/python/edges.py` and `typescript/edges.ts` build the NFC/NFD dictionary packet with the keys NFC (`c3 a9`) then NFD (`65 cc 81`), the descending order AZ-3329 fixed in the C# and Java probes. Since the loop 42 ascending-key rule the packet is refused; both print `INFO keys NFC 'é' and NFD 'e+U+0301': refused`, while the text of the Python line (and the TypeScript line when accepted) says "accepted as two keys (no normalization; Swift F47 differs)".

## Outcome

- Both probes pass NFD first; both print `accepted as two keys (no normalization; Swift F47 differs)` for the case.

## Scope

### Included
- The packet expression of the NFC/NFD case in `fixtures/hostile/fuzz/python/edges.py` and `fixtures/hostile/fuzz/typescript/edges.ts`, with a one-line comment.

### Excluded
- Any package file; the Swift probe (it refuses NFC and NFD of one key by an owner ruling, F47); the wording of the info lines.

## Acceptance Criteria

**AC-1: The case is accepted**
Given the Python probe (`python3.14 -I -B edges.py <repo>`) and the TypeScript probe (`node edges.ts <repo>` from `typescript/`)
When each runs
Then each prints `INFO keys NFC 'é' and NFD 'e+U+0301': accepted as two keys (no normalization; Swift F47 differs)` (it printed `refused` before)

**AC-2: Nothing else moves**
Given the same two runs before and after the change
When their other lines are compared (the load and microsecond figures aside)
Then exit 0 both times, 0 `FAIL`, and the other lines are equal (86 `PASS` lines in Python, 87 in TypeScript)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the NFC/NFD `INFO` line of each probe | `accepted as two keys` |
| AC-2 | the two runs | exit 0, 0 FAIL, other lines equal |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | smoke76 step 10 | both probes | as AC-1 | — |

## Constraints

- Edit the packet expression, not the `nfc` and `nfd` literals (the two strings look equal on screen and differ in bytes).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
