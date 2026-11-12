---
loop: 113
branch: dev
---

# Rust: a repeat that is not the last thing read is refused when the scheme is built

**Task**: AZ-4218_repeat_last_rust
**Name**: Rust: a repeat that is not the last thing read is refused when the scheme is built
**Description**: Rust refuses, when a scheme is built, a repeat that a byte-writing field follows or that sits inside a list or dict element, by the shared contract.
**Complexity**: 5 points
**Dependencies**: AZ-4210_repeat_last_hostile_cases_and_readme
**Component**: rust
**Tracker**: AZ-4218
**Epic**: AZ-4209

Written in loop 112 (2026-11-12) from the owner's decision on AZ-4206 ("Refuse at build"). Not claimed by a loop: the next `/autodev` picks it from `todo/`.

## Problem

A `repeat` has no count on the wire: unpack reads rounds until the buffer ends, so whatever a scheme writes after a repeat is read as more rounds. Both Rust APIs that have a `repeat` (the map form `MapScheme` and the heap-free `packbin::nostd`) build such a scheme, pack it and refuse their own bytes; two repeats in a row read back as two rounds of the first with no error. In the map form all repeats of a scheme share the one `__repeat__` key, so the rounds of two repeats cannot even be given apart. The owner decided on 2026-11-12 that such a scheme is refused when it is built, in all nine packages (`_docs/02_document/contracts/library/repeat-last.md`).

## Outcome

- A scheme of the refused cases cannot be built in Rust; the error says which repeat, which field follows it and to use `times`.
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
- The typed `Scheme` (it has no `repeat`).

## Acceptance Criteria

**AC-1: The refused cases are refused when the scheme is built**
Given the cases R1 to R6 of the contract, each written in the map form and in the heap-free API
When the scheme is built with `MapScheme::new` (map form) and checked with `nostd::validate` (heap-free API)
Then it is refused with the map form's scheme refusal (a panic with the contract's text, as its other scheme rules) and, in the heap-free API, `SchemeInvalid` with the id of the first field that follows the repeat; nothing is packed. R7 and R8 have no spelling in Rust (a list or dict element is one value) and R9 is refused today; the tests name the three so

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
When the whole feature matrix of `run-suite.sh rust` runs (`docker compose -f docker-compose.test.yml run --rm rust`)
Then 0 bytes differ; every scheme the rule refuses is rewritten with `times` or turned into a test of the refusal, and their number is in the batch report

**AC-5: The embedded row holds**
Given the `rust-m33f` row and the pins of `rust/embedded/limits-m33f.txt`
When `docker compose -f docker-compose.test.yml run --rm rust-embedded` runs after `rust/embedded/run.sh libs` (Rust 1.98)
Then the row passes; a pin that moved is set to the measured figure and `_docs/AGENT_GOTCHAS.md` says what the bytes bought; a growth above 256 B of flash or 64 B of stack on any set stops the task and goes to the owner

**AC-6: The probe shows the refusals**
Given the committed probe of loop 112
When `bash scripts/probes/repeat-followed-by-field/run.sh rust` runs
Then the build column says `refused` for `a`, `d`, `e-when`, `e-flags`, `f` in both forms (`b` and `c` keep the refusal of the row) and the `control` line still ends in `same`

## Non-Functional Requirements

**Compatibility**
- Packets are unchanged. The only behaviour change is that the refused schemes no longer build; it travels with the next release tag.

**Performance**
- One walk of the scheme when it is built; nothing per pack or unpack.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each refused case, each form (in the map form and in the heap-free API) | refused at build; the text (or status and field id) of the contract, compared whole |
| AC-1 | a field after the repeat that cannot write a byte (a `bool` bit of an earlier flag byte, a zero-width `bytes`), where the package can write it | builds |
| AC-2 | K1 to K5 | the contract's packet; the values read back |
| AC-3 | the new hostile cases | the outcome of `cases.txt`; skipped cases named |
| AC-5 | The embedded row holds | the row passes; a pin that moved is set to the measured figure and `_docs/AGENT_GOTCHAS.md` says what the bytes bought; a growth above 256 B of flash or 64 B of stack on any set stops the task and goes to the owner |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | the unchanged fixtures and vectors | the whole feature matrix of `run-suite.sh rust` runs (`docker compose -f docker-compose.test.yml run --rm rust`) | all pass; 0 bytes differ | Compatibility |
| AC-6 | the committed probe | `run.sh` for this package | refusals in the build column; `control` reads back | — |

## Constraints

- The rule is the contract `_docs/02_document/contracts/library/repeat-last.md` (version 1.0.0); a case this spec does not spell out is decided by the contract, not by this package's neighbours.
- No packet changes: a scheme that still builds packs and unpacks the same bytes as before.
- The check runs when the scheme is built and never looks at a row; nothing is added to pack or unpack.
- ADR-001: the package writes its own check; no shared walker and no generated scheme.
- In `rust/src/nostd` the check uses no call that links a panic path (`split_at_mut`, `chunks*`, `copy_from_slice`, ...; the list is in `_docs/AGENT_GOTCHAS.md`).
- A new variant on a public enum breaks every exhaustive `match` on it: the rule reuses `SchemeInvalid`.

## Risks & Mitigation

**Risk 1: A test of the package relies on a scheme the rule refuses**
- *Risk*: The package's own tests may pack a field after a repeat or a repeat inside an element on purpose (TypeScript has 4 such schemes; this package was not counted in loop 112).
- *Mitigation*: Run the suite with the check in place before anything else, list every scheme that stops building in the batch report, and rewrite each with `times` or as a test of the refusal; never weaken the check to keep a test.

**Risk 2: The check refuses a scheme that is readable**
- *Risk*: A too-wide notion of "follows" would refuse a repeat that is the last thing read (K1 to K5 of the contract).
- *Mitigation*: K1 to K5 are tests of this task, and the probe's `control` line must still end in `same`.

**Risk 3: The heap-free check costs flash on the device**
- *Risk*: `validate` grows, and the pins of the M33F row count the whole probe.
- *Mitigation*: Measure with `run.sh libs` then the `rust-embedded` stage; the budget of AC-5 decides.

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
