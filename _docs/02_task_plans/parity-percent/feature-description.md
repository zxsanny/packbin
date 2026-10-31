# Feature: parity as a percentage of the message (loop 97)

Estimate: 8 points. Scope high (8 packages, the reference, vectors, ring, contract, ADR, README), novelty low (the code, the bytes and the limits stay), risk medium (a wire rule for schemes that opt in). Applied lessons: estimation entries of `_docs/LESSONS.md` (touch every package once; run each reader of a shared shape).

## Description

A scheme may declare an integer percentage `p` (0 to 100) of parity instead of a fixed count `n`. At pack the parity count of a message is `n(p, L) = min(32, ceil(p × L / 100))` from its clear length `L`; at unpack the same count is found from the received length `N` alone, as the one `L` with `L + n(p, L) = N`. The bytes are exactly those of the existing code with that `n`. The fixed `with_parity(n)` stays. Full criteria: `acceptance_criteria.md` (AC-1 to AC-16); examples and the new vector row words: `input_data/expected_results/results_report.md`; usage rows: `scenarios.md`; interview: `problem.md`.

## Affected components and insertion points (read from source, HEAD fe7aeaf)

- Reference and fixtures: `scripts/ecc/eccfmt.py` (the count function and the inversion), `scripts/ecc/gen_vectors.py` and `check_vectors.py` (new rows `pct`, `encp`, `inv`, `fixp`, `badp`), `fixtures/ecc/vectors.txt`, `fixtures/ecc/README.md`, `check-contract.sh`.
- Cross-language ring: `scripts/ecc/gen_ring_cases.py`, `scripts/ecc/ring_ecc.py`, `fixtures/ecc/ring-cases.txt`, `.github/workflows/ring-ecc.sh` and its self-test, and the 8 ECC drivers (`handoff_ecc.py`, `handoff-ecc.ts`, `HandoffEcc.java`, the C# driver, the Go, Rust and Swift handoff projects, `handoff_ecc.cpp`).
- The 8 packages, each: the scheme setting beside `with_parity` (`Scheme`/`MapScheme`/`Scheme<Row>`), the codec call that takes the count, the dispatch rule (same setting on all handlers), the limit rule (AC-8), tests of AC-1 to AC-10. Files known: `csharp/Packbin.cs`, `go/ecc.go` `pack.go` `unpack.go`, `java/src/main/java/packbin/Scheme.java`, `rust/src/scheme/mod.rs` `field/map_scheme.rs` `nostd/scheme.rs` `nostd/ecc.rs` `walk/mod.rs`, `cpp/include/packbin/codec.hpp` `ecc.hpp` `core.hpp`, plus the Python, TypeScript and Swift scheme modules.
- Rust `DispatchHandler::parity()` has no default and is public: the percentage adds `parity_percent()` with a default of 0 so a hand-written handler still compiles.
- Embedded: C++ `PACKBIN_NO_ECC` removes the percentage; the Cortex-M33F pins (`m33f_*` in `cpp/embedded/lib.sh`) and the Rust `limits-m33f.txt` pins hold the 64 KB / 8 KB ceilings; a raised pin needs a line in `_docs/AGENT_GOTCHAS.md`.
- Docs: `_docs/02_document/contracts/library/message-ecc.md` (1.0.1 to 1.1.0), a new ADR `010_parity-percentage.md`, the README error-correction section (`README.md` line 861 onward, the per-package spelling table and the examples), component docs of the 8 packages, `module-layout.md`, `glossary.md`.

## Contract and ADR outcome (Step 4.5)

- Producer on `message-ecc` (public signature and a new rule): bump to 1.1.0 with a Change Log entry; known consumers are the 8 packages and the ring.
- ADR 007 (Accepted): aligned. It named "a per-scheme setting" and rejected only "parity always on, one fixed n". Drift: ADR 007 does not say `n` can follow the length. `> Affects ADR 007_message-error-correction: the count may be derived from the clear length`. The decision is recorded in the new ADR 010. ADR 001 (wire size = sum of present fields) keeps its one opt-in exception, now with a length-derived count.
- Layout delta: Public API surface change in all 8 components: `module-layout.md` Public API rows get the new setter.

## Fit decisions (Step 4.7)

One problem card, auto-applied (clearly recommended, no peer):

- **What breaks:** a percentage makes `n` depend on the message, so a repair limit `t` that was checked against `n / 2` before any byte is read (today's `bad_limit`) cannot be checked until the length is known. Who: a caller that sets one `t` for messages of different sizes.
- **Options:** A, lower `t` to this message's `n / 2` and keep `bad_limit` only for `t` outside 0 to 16 (recommended: short messages still unpack, the repaired count is the real one). B, refuse with `bad_limit` when `t` is above this message's `n / 2` (a caller must know every message's size; short packets fail for a limit that suits long ones). C, drop `t` and always repair `n / 2` (loses detect-only, which the contract makes the default).
- **Chosen:** A (`AC-8`). Resolved.

## Scenarios

Source file `scenarios.md` (S1 to S12, all confirmed):

| # | Axis | Actor / trigger / state | Behavior | Status | AC |
|---|------|--------------------------|----------|--------|----|
| S1 | first use | A developer sets 25 % on a scheme and packs a 40-byte message | 10 parity bytes follow, 50 bytes sent | confirmed | AC-1, AC-3 |
| S2 | repeat | The same scheme packs messages of 10, 40 and 100 bytes | 3, 10 and 25 parity bytes: the count follows each message | confirmed | AC-1 |
| S3 | concurrent | Two threads pack and unpack with one scheme | Schemes are immutable data and `n` is a pure function of `L`; nothing shared changes | confirmed | AC-1 |
| S4 | partial failure | A packet loses its last byte, the shorter length is one no `L` gives | `uncorrectable`, no values | confirmed | AC-6 |
| S5 | partial failure | A packet loses bytes and the shorter length is again a valid length | The code check fails (the length byte is covered); `uncorrectable`, or a repair to another message only within the limits of the table in the contract | confirmed | AC-5, AC-7 |
| S6 | permission denied | — | Not applicable: no actor, no secret | confirmed | out of scope (library) |
| S7 | invalid input | 101 %, -1 %, or a percentage together with a fixed count in a constructor | Refused when the scheme is built, `bad_parity` | confirmed | AC-9 |
| S8 | invalid input | Repair limit above 16, or below 0 | `bad_limit` before any byte is read; a limit 0 to 16 above this message's `n / 2` is lowered to it | confirmed | AC-8 |
| S9 | existing data | An 0.4.0 sender with `with_parity(4)` and a new receiver with the same scheme | Same bytes, same errors | confirmed | AC-11 |
| S10 | undo | A fleet moves from 25 % back to 0 % or to a fixed count | A wire change for both ends, as changing `n` is today; the contract says both ends share the setting | confirmed | AC-9, AC-14 |
| S11 | boundaries | L 0, the largest L, the largest L + 1, N 254, N 255 | L 0 sends 0 bytes and unpacks as empty; the largest L fits in 254; one more is `too_long`; N 255 is `too_long` | confirmed | AC-4, AC-6 |
| S12 | existing-feature overlap | Dispatch by type byte, optional fields and compact text under a percentage | Dispatch needs one setting on all handlers, repair comes first then dispatch; optional fields only change `L` and so `n`; text is read after the repair | confirmed | AC-10 |


## Flagged concerns

| concern | policy / owner | status | severity |
|---|---|---|---|
| The count must be recoverable from the received length alone, so the formula is exact and identical in 8 languages | AC-1, AC-5; vectors `pct`, `inv` | open | Medium |
| A wire change for schemes that opt in; contract bump | contract 1.1.0, fixed-count schemes byte-identical (AC-11) | open | Medium |
| C++ and Rust flash and stack pins, `PACKBIN_NO_ECC` builds | AC-13; figures measured on HEAD at implement time | open | Medium |
| Repair limit semantics for a length-derived count | problem card above, option A | resolved | Low |
