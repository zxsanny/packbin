---
loop: 35
branch: dev
---

# Docs: README, schema and glossary for compact text

**Task**: AZ-2658_compact_text_docs
**Name**: Docs: README, schema and glossary for compact text
**Description**: The documents say how a string is written now, in every language, and that the wire changed.
**Complexity**: 2 points
**Dependencies**: AZ-2657
**Component**: docs
**Tracker**: AZ-2658
**Epic**: AZ-2645

## Problem

The README, `schema.md` and the hostile README still describe a 2-byte count plus UTF-8, and the README snippets are run by tests that will fail until they match.

## Outcome

- Every document that states the string wire rule states the new one; every code-drift test passes.

## Scope

### Included
- `README.md`: data types row `utf8` (1140), `### UTF-8` (1231-1244), List and Dictionary (1246-1288), C++ notes (362, 447: `Text<N>` or `Packed`, scratch, `PACKBIN_NO_TEXT`), Go (577, 583, 649), Swift (784-794), Untrusted input (1571-1580); a short section on the compact text format and the wire change (no version byte; no tag was published).
- `_docs/01_solution/schema.md` string rules; `fixtures/hostile/README.md` wire rules; `_docs/02_document/glossary.md` (compact text, mode, escape, raw fallback); `architecture.md` Vision principles (the codec is a runtime primitive, ADR 001 and 006); `module-layout.md`; `interaction-risks.md`.

### Excluded
- Code (other tasks).

## Acceptance Criteria

**AC-1: Wire rule updated**
Given the README, schema and hostile README
When the string wire rule is searched
Then no text says "2-byte count then UTF-8" for a string field; each points to the contract

**AC-2: Examples run**
Given README snippets with strings and the code-drift tests (Go `Example` tests, Swift `CollectionReadmeTests`, the other packages' README tests)
When the suites run
Then all pass and print the documented bytes

**AC-3: Glossary and vision**
Given `glossary.md`, `architecture.md`, `module-layout.md`
When they are read
Then compact text, mode, escape and raw fallback are defined; the C++ "allocates nothing" principle names the scratch rule

## Non-Functional Requirements

**Compatibility**
- Links stay valid (checked by the existing doc link check if any).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | README drift tests | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | repository text search | grep for the old rule | no hit | — |

## Constraints

- The wire format is the one in `_docs/02_document/contracts/library/compact-text.md` (AZ-2646). A language never invents a choice the contract fixes (tie-breaks, table order, pad bits).
- The encoder works on the UTF-8 bytes this package already produces for a string today, so lone-surrogate and invalid-input behavior of the language does not change (fit decision, feature-description).
- Positions: a string field, a list element, a dictionary key, a dictionary value that is a list of strings, a string under `repeat`, `times` or `flags` (scenario S12). Dictionary pairs are still sorted by the key's UTF-8 bytes before the keys are encoded; a repeated decoded key is refused (S10).


## Contract

Consumer of `compact-text.md`.


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire break: packets with strings written before this loop cannot be read | Owner accepted 2026-10-18 (no tag was ever published) | accepted-risk | Medium |
