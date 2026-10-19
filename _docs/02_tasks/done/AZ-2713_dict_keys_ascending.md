# Dict keys: strictly ascending on unpack in all eight packages

**Task**: AZ-2713_dict_keys_ascending
**Name**: Dict keys strictly ascending on unpack
**Description**: Every package refuses a dict whose decoded keys are not in strictly ascending UTF-8 byte order, so the repeated-key check is one compare per key (F51, F56).
**Complexity**: 8 points (estimate from the loop 41 audit; `/new-task` re-checks, 8 hands off to `/decompose`)
**Dependencies**: None
**Component**: compact-text (all 8 packages)
**Tracker**: AZ-2713
**Epic**: AZ-2645

## Problem

The C++ core keeps no set, so `check_new_key` (`cpp/src/core/unpack.cpp:217-229`) compares each decoded key with every earlier entry of a bound dict: 16,384 keys in a 98 KB packet take 1.06 s, 65,535 keys 16.9 s (security report F51, Medium, owner 2026-10-19). A C++ dict that is not bound accepts repeated keys the other seven refuse (F56). Every encoder already writes the pairs sorted by the key's UTF-8 bytes (`compact-text.md` invariants), so only hand-made or hostile packets carry keys out of order.

## Outcome

- One rule in the contract and in all eight decoders: a dict key must be strictly greater than the key before it (by decoded UTF-8 bytes); equal is a repeated key, smaller is out of order; both refuse the packet with the package's existing dict-key error.
- The repeated-key check becomes one compare with the previous key in every package; C++ needs no storage for it and checks unbound dicts too.

## Scope

### Included
- `compact-text.md` (invariants and the C++ section), the decoders of all eight packages, `fixtures/text/vectors.txt` or `fixtures/hostile/cases.txt` rows, the ring packets, the README dict line, the C++ capacity note of loop 41 (remove it once the cost is linear).
- The Cortex-M4F flash and stack gates (`AGENT_GOTCHAS.md`: 60 B flash margin) for the C++ change.

### Excluded
- The encoders (already sorted); the Swift stream-safe key check (F47, unchanged).

## Acceptance Criteria

**AC-1: Out of order is refused**
Given a dict packet whose second key sorts before its first
When it is unpacked in each of the eight packages
Then it is refused with that package's dict-key error and no row

**AC-2: Repeated keys are refused, bound or not**
Given a dict packet with one key twice (also in two byte forms: compact and raw)
When it is unpacked, the dict bound and (C++) unbound
Then it is refused in all eight

**AC-3: Linear cost**
Given 65,535 distinct ascending keys (and, C++, a bound `Array` of that capacity)
When the packet is unpacked
Then each package takes at most 1 s on the CI runner

**AC-4: Canonical packets unchanged**
Given the existing text vectors, ring packets and golden packet
When they are unpacked
Then every result is the same as before

## Candidates for the same loop (loop 41 Lows, `_docs/05_security/security_report.md`)

F57 (C++ session spends a receive position on an invalid scheme), F58 (Python session pad cost before the type byte), F59 (C# and Go repair allocations), F60 (Rust decoded-string capacity), F19 instances (Python and TypeScript session payload type checks).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Stricter decoders are a wire-acceptance change | free until the first `v*` tag (owner, loop 35) | open | Low |
| C++ flash margin 60 B on Cortex-M4F | `AGENT_GOTCHAS.md` | open | Medium |
