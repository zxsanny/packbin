# Shared: hostile cases and README text for "a repeat must be last"

**Task**: AZ-4210_repeat_last_hostile_cases_and_readme
**Name**: Shared: hostile cases and README text for "a repeat must be last"
**Description**: `fixtures/hostile` gains the cases of the rule and the root README states it, so the nine package tasks replay one file and quote one text.
**Complexity**: 2 points
**Dependencies**: None
**Component**: fixtures/hostile, README (docs)
**Tracker**: AZ-4210
**Epic**: AZ-4209

Written in loop 112 (2026-11-12) from the owner's decision on AZ-4206 ("Refuse at build"). Not claimed by a loop: the next `/autodev` picks it from `todo/`.

## Problem

The rule "a repeat is the last thing a packet reads" (`_docs/02_document/contracts/library/repeat-last.md`, owner decision 2026-11-12) has no shared fixture, and the README says only "A field after `repeat` is eaten as another point. Use `times` when something follows the group". Without shared cases each package would pin its own reading of the rule, which is how the nine came to disagree with their own unpack (`_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`).

## Outcome

- `cases.txt` holds the refused shapes as `construct` cases and the shapes that must keep building as `pack` cases with their bytes.
- The README states the rule where a reader meets `repeat`, lists it among the scheme mistakes refused at build, and tells an upgrader what stops building.
- The contract names its producer and consumers by ticket.

## Scope

### Included
- `fixtures/hostile/cases.txt` and `fixtures/hostile/README.md`: the new cases and their sections (scheme, expected outcome, `Run by` / `Not run by` for the `pack` cases, the packages that cannot write a case and why).
- `README.md`: the Repeat section, the scheme-mistake list under Untrusted input, "If you upgrade", and the sentences that describe today's behaviour (a field after an inner repeat "reads back differently", the Java inner repeat, the lines "Schemes Go / Swift / Dart refuses and TypeScript builds" where they touch this rule).
- `_docs/02_document/contracts/library/repeat-last.md`: the Producer and Consumer lines; a correction with its reason if a package task finds a case that does not reproduce.
- `_docs/02_document/module-layout.md`: the case count of `fixtures/hostile`.

### Excluded
- The checks in the packages and the loaders' scheme tables (the nine package tasks).
- Any change to the 75 existing cases.
- The wire format.

## Acceptance Criteria

**AC-1: The refused shapes are shared cases**
Given the cases R1 to R9 of the contract
When `cases.txt` is read
Then each is a `construct` case with the outcome `scheme_error` and a section in `fixtures/hostile/README.md` that writes the scheme in the file's notation and names the packages that cannot write it (R7 and R8 in Rust and in bound C++ lists), with the reason

**AC-2: The shapes that keep building are shared cases**
Given the cases K1 to K4 of the contract
When `cases.txt` is read
Then each is a `pack` case with the outcome `bytes` and the contract's packet (`01090506`, `01010506`, `0103090506`, `0102050609`), with `Scheme`, `Row`, `Run by` and `Not run by` lines

**AC-3: The file stays valid**
Given the 75 older cases
When `check-cases.sh` and `cases.test.sh` run
Then both pass and the 75 older lines are byte-identical

**AC-4: The README states the rule**
Given the README sections on Repeat, Untrusted input and upgrading
When a reader looks for what may follow a repeat
Then the rule, the refusal text of the contract and the three kinds of scheme that built before and now do not are stated; no sentence still describes a field after a repeat as something that packs

**AC-5: The contract names its tasks**
Given the contract file
When it is read
Then the Producer line names AZ-4210 and the Consumer line AZ-4211 to AZ-4219

## Non-Functional Requirements

**Compatibility**
- No existing case changes; a loader that does not know a new id fails loudly, so this task lands before or together with the package tasks of the same loop.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `check-cases.sh` on the new `construct` lines | valid: id, stage, outcome, `-` for the hex, a section per id |
| AC-2 | `check-cases.sh` on the new `pack` lines | valid: `bytes`, a packet starting with `01`, the two `Run by` lists name each of the nine packages once |
| AC-3 | `cases.test.sh` | passes; a corrupted copy of a new line fails the check |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | the committed file | `bash fixtures/hostile/check-cases.sh` and `bash fixtures/hostile/cases.test.sh` | both pass | Compatibility |
| AC-4 | the README | the Swift README snippet test and the C# README example build (they read the README) | pass | — |

## Constraints

- The cases are the contract's (`_docs/02_document/contracts/library/repeat-last.md`); the file holds bytes and outcomes only, each package writes the schemes by hand (ADR-001).
- K5 (the split flag-byte form) is not a shared case: not every package has that form; the packages that have it pin it in their own tests.
- The README is one file: this task makes every README edit of the feature, the package tasks make none.

## Risks & Mitigation

**Risk 1: A package suite is red between this task and its own task**
- *Risk*: Each loader fails on an id it has no scheme for, so after this task lands the nine suites are red on the new ids until their task lands.
- *Mitigation*: Do the feature in one loop, this task first; a worker of a package task runs its suite after it added its schemes. The loop's one total test run is the gate.

**Risk 2: A packet of K1 to K4 does not reproduce in a package**
- *Risk*: The four packets were run in TypeScript only (loop 112).
- *Mitigation*: A package task replays them on its unchanged code first; a difference is reported and the case corrected here with the reason, as the hex-provenance rule of `fixtures/hostile/README.md` says.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Schemes that read back only for some rows (a list of one item, a `when` that is not taken, a clear flag bit, two `when`s that cannot both be taken) stop building | owner, 2026-11-12: "Refuse at build"; the `when` exception was offered and not taken, it can be added later | resolved | Medium |
| Java and C++ refuse a repeat inside a round at build (R9) although the owner was not asked about it separately | agent default of loop 112 from the chosen rule; the owner can overrule it before the Java and C++ tasks start | open | Low |

## Contract

This task produces the shared cases of the contract at `_docs/02_document/contracts/library/repeat-last.md` and keeps its text in step with the README.
Consumers (AZ-4211 to AZ-4219) MUST read that file, not this task spec, to discover the rule.
