---
loop: 113
branch: dev
---

# C++: a repeat that is not the last thing read is refused when the scheme is built

**Task**: AZ-4219_repeat_last_cpp
**Name**: C++: a repeat that is not the last thing read is refused when the scheme is built
**Description**: C++ refuses, when a scheme is built, a repeat that a byte-writing field follows or that sits inside a list or dict element, by the shared contract.
**Complexity**: 5 points
**Dependencies**: AZ-4210_repeat_last_hostile_cases_and_readme
**Component**: cpp
**Tracker**: AZ-4219
**Epic**: AZ-4209

Written in loop 112 (2026-11-12) from the owner's decision on AZ-4206 ("Refuse at build"). Not claimed by a loop: the next `/autodev` picks it from `todo/`.

## Problem

A `repeat` has no count on the wire: unpack reads rounds until the buffer ends, so whatever a scheme writes after a repeat is read as more rounds. C++ builds such a scheme, packs it and its own unpack answers `ShortPacket`; two repeats in a row read back with the second array empty and no error. The unbound form `list(element)` builds with a repeat inside the element, and a `repeat` inside a `repeat` or `times` round is allowed. The owner decided on 2026-11-12 that such a scheme is refused when it is built, in all nine packages (`_docs/02_document/contracts/library/repeat-last.md`).

## Outcome

- A scheme of the refused cases cannot be built in C++; the error says which repeat, which field follows it and to use `times`.
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

## Acceptance Criteria

**AC-1: The refused cases are refused when the scheme is built**
Given the cases R1 to R6 of the contract, each written as a run-time scheme and as a `constexpr` scheme
When the scheme is built with `scheme<Row>(...)` and checked (`validate`, and as a `constexpr` scheme)
Then it is refused with `SchemeInvalid` with the id of the first field that follows the repeat for a run-time scheme, and a compile error for a `constexpr` scheme (a compile-fail test per kind of case); nothing is packed. R7 to R9 are the next two criteria

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
When the suite runs with Apple clang and with GCC 16 (`docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`), the string-free and ECC-free builds included
Then 0 bytes differ; every scheme the rule refuses is rewritten with `times` or turned into a test of the refusal, and their number is in the batch report

**AC-5: A repeat inside an element or a round is refused**
Given R7 and R8 in the unbound form `list(element)` / `dict(element)`, and R9, a `repeat` inside a `repeat` or `times` round
When the scheme is checked
Then each is `SchemeInvalid` (a compile error for a `constexpr` scheme); the bound list and dict keep their refusal of a row element; a `times` inside a round still builds

**AC-6: The embedded rows hold**
Given the `cpp-m33f` row with its frame and small images, the Uno target and the ESP core stage
When `docker compose -f docker-compose.test.yml run --rm cpp-embedded` and `bash cpp/embedded/run.sh host esp core` run
Then all pass; the check is paid at compile time for a `constexpr` scheme, so the pins are expected not to move; a pin that moved is set to the measured figure and `_docs/AGENT_GOTCHAS.md` says what the bytes bought; a growth above 256 B of flash or 64 B of stack stops the task and goes to the owner

**AC-7: The probe shows the refusals**
Given the committed probe of loop 112
When `bash scripts/probes/repeat-followed-by-field/run.sh cpp` runs
Then the build column says `refused` for `a`, `d`, `e-when`, `e-flags`, `f`, `b-unbound`, `c-unbound` (the bound `b` and `c` keep the refusal of the row) and the `control` line still ends in `same`

## Non-Functional Requirements

**Compatibility**
- Packets are unchanged. The only behaviour change is that the refused schemes no longer build; it travels with the next release tag.

**Performance**
- One walk of the scheme when it is built; nothing per pack or unpack.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each refused case, each form (as a run-time scheme and as a `constexpr` scheme) | refused at build; the text (or status and field id) of the contract, compared whole |
| AC-1 | a field after the repeat that cannot write a byte (a `bool` bit of an earlier flag byte, a zero-width `bytes`), where the package can write it | builds |
| AC-2 | K1 to K5 | the contract's packet; the values read back |
| AC-3 | the new hostile cases | the outcome of `cases.txt`; skipped cases named |
| AC-5 | A repeat inside an element or a round is refused | each is `SchemeInvalid` (a compile error for a `constexpr` scheme); the bound list and dict keep their refusal of a row element; a `times` inside a round still builds |
| AC-6 | The embedded rows hold | all pass; the check is paid at compile time for a `constexpr` scheme, so the pins are expected not to move; a pin that moved is set to the measured figure and `_docs/AGENT_GOTCHAS.md` says what the bytes bought; a growth above 256 B of flash or 64 B of stack stops the task and goes to the owner |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | the unchanged fixtures and vectors | the suite runs with Apple clang and with GCC 16 (`docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`), the string-free and ECC-free builds included | all pass; 0 bytes differ | Compatibility |
| AC-7 | the committed probe | `run.sh` for this package | refusals in the build column; `control` reads back | — |

## Constraints

- The rule is the contract `_docs/02_document/contracts/library/repeat-last.md` (version 1.0.0); a case this spec does not spell out is decided by the contract, not by this package's neighbours.
- No packet changes: a scheme that still builds packs and unpacks the same bytes as before.
- The check runs when the scheme is built and never looks at a row; nothing is added to pack or unpack.
- ADR-001: the package writes its own check; no shared walker and no generated scheme.
- The core takes standard names only from `packbin/platform.hpp` (the `cpp-avr-uno` target has no C++ library).
- A new `cpp/src/core/*.cpp` changes the source count of `cpp/embedded/esp.sh` and the list of `.github/workflows/ring-lib.sh`; prefer the existing sources.
- `make -C cpp clean` between the host build and the `gcc:16` container (they share `cpp/build`).

## Risks & Mitigation

**Risk 1: A test of the package relies on a scheme the rule refuses**
- *Risk*: The package's own tests may pack a field after a repeat or a repeat inside an element on purpose (TypeScript has 4 such schemes; this package was not counted in loop 112).
- *Mitigation*: Run the suite with the check in place before anything else, list every scheme that stops building in the batch report, and rewrite each with `times` or as a test of the refusal; never weaken the check to keep a test.

**Risk 2: The check refuses a scheme that is readable**
- *Risk*: A too-wide notion of "follows" would refuse a repeat that is the last thing read (K1 to K5 of the contract).
- *Mitigation*: K1 to K5 are tests of this task, and the probe's `control` line must still end in `same`.

**Risk 3: The check costs flash on the device**
- *Risk*: A run-time scheme pays for the walk; the M33F pins are 25,948 B and 740 B.
- *Mitigation*: Keep the check in the `constexpr`-foldable scheme check, as the empty-body rule; measure the row; the budget of AC-6 decides.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Schemes that read back only for some rows (a list of one item, a `when` that is not taken, a clear flag bit, two `when`s that cannot both be taken) stop building | owner, 2026-11-12: "Refuse at build"; the `when` exception was offered and not taken, it can be added later | resolved | Medium |
| A sender that only packs for a reader of its own loses the scheme | owner, 2026-11-12: accepted with the same decision (the flagged concern of AZ-4206) | resolved | Medium |
| The number of this package's own test schemes the rule refuses was not measured in loop 112 | this task: counted on the first run, recorded in the batch report | open | Low |
| A repeat inside a round is refused at build in C++ although the owner was not asked about it separately | agent default of loop 112 from the chosen rule ("the last thing a packet reads"); the owner can overrule it before this task starts | open | Low |

## Document Dependencies

- `_docs/02_document/contracts/library/repeat-last.md` (the rule, the refused and still-building cases, the refusal text). Read the contract, not the spec of another package.
- `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md` (what this package does today, per shape).
- `fixtures/hostile/README.md` (the sections of the new cases).
