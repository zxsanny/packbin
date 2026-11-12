# Feature: a repeat must be the last thing a packet reads

Written in loop 112 (2026-11-12) as the handoff of AZ-4206 (AC-3) to `/decompose --feature`. Epic AZ-4209. Sized at 8 points or more (nine packages, one shared rule, embedded rows in two of them), so it is ten tasks and not one.

## What and why

A `repeat` has no count on the wire: unpack reads rounds until the buffer ends. Whatever a scheme writes after a repeat is read as more rounds. Loop 112 measured it in all nine packages with committed probes (`scripts/probes/repeat-followed-by-field/`, findings `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`): a field after a repeat, or a repeat inside a list or dict element, builds and packs bytes the package's own unpack refuses, and two repeats in a row are read back as other values with no error.

The owner decided on 2026-11-12: such a scheme is refused when it is built, in every package. The rule, its cases and its text are the contract `_docs/02_document/contracts/library/repeat-last.md`. No packet changes; the wire format of `repeat` does not change.

Who it is for: anyone who writes a scheme. Today the mistake shows up on the receiver, as a short packet or a wrong row; after the feature it shows up once, when the scheme is written, with a message that says to use `times`.

## Affected components

All nine packages (their scheme-build checks, beside the empty-round-body rule of loop 21), the shared hostile cases (`fixtures/hostile/`), the root `README.md`. No new module, no public signature, no dependency. Insertion points seen in loop 112: TypeScript `rounds.ts` and the `Scheme` constructor; C# `RoundScopes.cs`; Python `_validate.py`; Java `SchemeOrder.java`; Go `counted.go`; Swift `Counted.swift`; Dart `lib/src/checks.dart`; Rust `field/round_body.rs`, `field/shape.rs` and `nostd/check.rs`; C++ the scheme check behind `SchemeInvalid`.

Existing tests that pin today's behaviour: TypeScript 4 schemes in 3 files (measured by `scripts/probes/repeat-followed-by-field/rule-count/run.sh`); the other eight suites were not counted. Shared fixtures, golden vectors and ring driver schemes the rule refuses: 0 (measured in TypeScript, which runs the shared hostile cases and the ring driver).

## Scenarios

| id | scenario | status | behavior (confirmed) | AC ref |
|----|----------|--------|----------------------|--------|
| S1 | a scheme has a byte-writing field after a repeat at the top level | confirmed | refused when the scheme is built; the text names the repeat and the field and says to use `times` | AZ-4210 AC-1 (case R1); AC-1 of AZ-4211 to AZ-4219 |
| S2 | the field stands after a `when`, a `flags`, a group or a nested row that holds the repeat | confirmed | refused the same way | AZ-4210 AC-1 (R2, R3, R4); AC-1 of AZ-4211 to AZ-4219 |
| S3 | a second repeat follows a repeat | confirmed | refused the same way (today it reads back wrong values with no error) | AZ-4210 AC-1 (R5); AC-1 of AZ-4211 to AZ-4219 |
| S4 | the field after the repeat sits under a `when` that cannot be taken together with the repeat's `when` | confirmed | refused all the same (owner: the exception was offered and not taken; it can be added later) | AZ-4210 AC-1 (R6); AC-1 of AZ-4211 to AZ-4219 |
| S5 | a repeat sits inside a list or dict element | confirmed | refused when the scheme is built; a package whose element cannot be a row keeps its refusal of the row | AZ-4210 AC-1 (R7, R8); AC-1 of AZ-4211 to AZ-4217; AZ-4218 AC-1; AZ-4219 AC-5 |
| S6 | a repeat sits inside a `repeat` or `times` round (Java and C++ build it today) | confirmed | refused when the scheme is built, as in the other seven; a `times` inside a round keeps building | AZ-4210 AC-1 (R9); AZ-4214 AC-5; AZ-4219 AC-5 |
| S7 | the repeat is the last thing read: at the top level, or the last thing inside a `when` or `flags` that nothing follows | confirmed | builds; the packet is unchanged | AZ-4210 AC-2 (K1, K2, K3); AC-2 of AZ-4211 to AZ-4219 |
| S8 | a field after the repeat cannot write a byte (a `bool` bit of an earlier flag byte, a zero-width `bytes`) | confirmed | builds | contract K5; AC-2 and the unit row of AC-1 of AZ-4211 to AZ-4219 |
| S9 | a `times` is followed by fields, or sits inside an element | confirmed | unchanged: it builds and packs as before | AZ-4210 AC-2 (K4); AC-2 of AZ-4211 to AZ-4219 |
| S10 | an existing packet, fixture, golden vector or ring handoff | confirmed | 0 bytes differ | AZ-4210 AC-3; AC-4 of AZ-4211 to AZ-4219 |
| S11 | a package's own test or README example uses a refused scheme | confirmed | rewritten with `times` or turned into a test of the refusal; the README says what stops building after an upgrade | AZ-4210 AC-4; AC-4 of AZ-4211 to AZ-4219 |
| S12 | the check runs on a device (the heap-free Rust API, a run-time C++ scheme) | confirmed | the embedded rows pass; a pin that moves is set to the measured figure with a note, above 256 B of flash or 64 B of stack the owner decides | AZ-4218 AC-5; AZ-4219 AC-6 |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | schemes that read back only for some rows (one list item, a `when` not taken, a clear flag bit, two `when`s that cannot both be taken) stop building | owner, 2026-11-12: refuse at build; the `when` exception is not taken now | yes: every task, `## Flagged concerns` (resolved) and the contract's Decisions |
| 2 | a sender that only packs for a reader of its own loses the scheme | owner, 2026-11-12: accepted with the same decision | yes: every package task, `## Flagged concerns` (resolved) |
| 3 | Java and C++ build a repeat inside a round today; the README documents it as a trap | agent default (the owner can overrule it): refuse at build, as the other seven | yes: AZ-4214, AZ-4219 and AZ-4210, `## Flagged concerns` (open, Low) |
| 4 | the check adds code to the two packages that run on a device | agent default: the pins follow the measured figure with a note; a growth above 256 B of flash or 64 B of stack goes to the owner | yes: AZ-4218 AC-5, AZ-4219 AC-6 |
| 5 | every hostile loader fails on a case id it has no scheme for, so the shared cases and the nine loaders must land in one loop | the shared task first, the packages after it, one total test run at the end | yes: AZ-4210 Risks; `_dependencies_table.md` |

## Order

AZ-4210 first (the cases every loader replays). Then the packages, which write disjoint directories: TypeScript (the reference), C#, Python, Java; then Go, Swift, Dart, Rust; then C++ with its embedded rows. One total review and one total test run for the loop.
