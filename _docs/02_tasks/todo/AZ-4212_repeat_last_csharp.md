# C#: a repeat that is not the last thing read is refused when the scheme is built

**Task**: AZ-4212_repeat_last_csharp
**Name**: C#: a repeat that is not the last thing read is refused when the scheme is built
**Description**: C# refuses, when a scheme is built, a repeat that a byte-writing field follows or that sits inside a list or dict element, by the shared contract.
**Complexity**: 3 points
**Dependencies**: AZ-4210_repeat_last_hostile_cases_and_readme
**Component**: csharp
**Tracker**: AZ-4212
**Epic**: AZ-4209

Written in loop 112 (2026-11-12) from the owner's decision on AZ-4206 ("Refuse at build"). Not claimed by a loop: the next `/autodev` picks it from `todo/`.

## Problem

A `repeat` has no count on the wire: unpack reads rounds until the buffer ends, so whatever a scheme writes after a repeat is read as more rounds. C# builds every such scheme, packs it and its own `Unpack` answers `ShortPacket`; two repeats in a row read back with the second collection empty and no error. The owner decided on 2026-11-12 that such a scheme is refused when it is built, in all nine packages (`_docs/02_document/contracts/library/repeat-last.md`).

## Outcome

- A scheme of the refused cases cannot be built in C#; the error says which repeat, which field follows it and to use `times`.
- A repeat that is the last thing read builds and packs as before.
- The package answers the shared hostile cases like the other eight.

## Scope

### Included
- The scheme-build check and its tests.
- The package's hostile loader: the new cases.
- The package's own tests and examples that used a refused scheme.

### Excluded
- The other packages (their own tasks).
- The root `README.md` and `fixtures/hostile/` (AZ-4210).
- The wire format of `repeat`; `times`; unpack.
- A public reader for dictionary rows (a known gap: the dictionary form cannot show a read-back; it is not this rule).

## Acceptance Criteria

**AC-1: The refused cases are refused when the scheme is built**
Given the cases R1 to R8 of the contract, each written with typed rows (a repeat bound to a collection of rows) and with an unbound `Field.Repeat` over a dictionary row
When the scheme is built with the `Scheme` constructor
Then it is refused with an `ArgumentException` carrying the contract's text (the repeat and the member that follows it); nothing is packed. R9 keeps today's refusal by the nesting rule and its text

**AC-2: A repeat that is last still builds, with the same bytes**
Given the cases K1 to K5 of the contract that the package can write
When each is built, packed with the contract's values and unpacked
Then the packet is the contract's packet and the values come back

**AC-3: The shared hostile cases are replayed**
Given the cases AZ-4210 added to `fixtures/hostile/cases.txt`
When the package's hostile test runs
Then every `construct` case is a scheme error and every `pack` case gives its bytes; a case the package cannot write is named as skipped with its reason, none silently

**AC-4: Nothing else changes**
Given the fixtures, the golden vectors, the ring handoffs and the package's own tests and README examples
When the whole suite runs on `net10.0` and on `netstandard2.0` (`env MSBUILDDISABLENODEREUSE=1`)
Then 0 bytes differ; every scheme the rule refuses is rewritten with `times` or turned into a test of the refusal, and their number is in the batch report

**AC-5: The probe shows the refusals**
Given the committed probe of loop 112
When `bash scripts/probes/repeat-followed-by-field/run.sh csharp` runs
Then the build column says `refused` for `a`, `b`, `c`, `d`, `e-when`, `e-flags`, `f` and the `control` line still ends in `same`

## Non-Functional Requirements

**Compatibility**
- Packets are unchanged. The only behaviour change is that the refused schemes no longer build; it travels with the next release tag.

**Performance**
- One walk of the scheme when it is built; nothing per pack or unpack.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each refused case, each form (with typed rows (a repeat bound to a collection of rows) and with an unbound `Field.Repeat` over a dictionary row) | refused at build; the text (or status and field id) of the contract, compared whole |
| AC-1 | a field after the repeat that cannot write a byte (a `bool` bit of an earlier flag byte, a zero-width `bytes`), where the package can write it | builds |
| AC-2 | K1 to K5 | the contract's packet; the values read back |
| AC-3 | the new hostile cases | the outcome of `cases.txt`; skipped cases named |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | the unchanged fixtures and vectors | the whole suite runs on `net10.0` and on `netstandard2.0` (`env MSBUILDDISABLENODEREUSE=1`) | all pass; 0 bytes differ | Compatibility |
| AC-5 | the committed probe | `run.sh` for this package | refusals in the build column; `control` reads back | — |

## Constraints

- The rule is the contract `_docs/02_document/contracts/library/repeat-last.md` (version 1.0.0); a case this spec does not spell out is decided by the contract, not by this package's neighbours.
- No packet changes: a scheme that still builds packs and unpacks the same bytes as before.
- The check runs when the scheme is built and never looks at a row; nothing is added to pack or unpack.
- ADR-001: the package writes its own check; no shared walker and no generated scheme.

## Risks & Mitigation

**Risk 1: A test of the package relies on a scheme the rule refuses**
- *Risk*: The package's own tests may pack a field after a repeat or a repeat inside an element on purpose (TypeScript has 4 such schemes; this package was not counted in loop 112).
- *Mitigation*: Run the suite with the check in place before anything else, list every scheme that stops building in the batch report, and rewrite each with `times` or as a test of the refusal; never weaken the check to keep a test.

**Risk 2: The check refuses a scheme that is readable**
- *Risk*: A too-wide notion of "follows" would refuse a repeat that is the last thing read (K1 to K5 of the contract).
- *Mitigation*: K1 to K5 are tests of this task, and the probe's `control` line must still end in `same`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Schemes that read back only for some rows (a list of one item, a `when` that is not taken, a clear flag bit, two `when`s that cannot both be taken) stop building | owner, 2026-11-12: "Refuse at build"; the `when` exception was offered and not taken, it can be added later | resolved | Medium |
| A sender that only packs for a reader of its own loses the scheme | owner, 2026-11-12: accepted with the same decision (the flagged concern of AZ-4206) | resolved | Medium |
| The number of this package's own test schemes the rule refuses was not measured in loop 112 | this task: counted on the first run, recorded in the batch report | open | Low |

## Document Dependencies

- `_docs/02_document/contracts/library/repeat-last.md` (the rule, the refused and still-building cases, the refusal text). Read the contract, not the spec of another package.
- `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md` (what this package does today, per shape).
- `fixtures/hostile/README.md` (the sections of the new cases).
