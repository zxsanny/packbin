# Ripple log — loop 21

One pass. Scope: all six packages (`git show 3acc589`, 113 paths; specs AZ-2373 and AZ-2381 to AZ-2394). Mode: the batch report `batch_01_loop21_report.md`, `test_run_loop21_report.md`, `reference_loop21_slots.md`, `review21.md`, `assessment21.md`, `problem.md` (D1 to D10), the specs, then the changed source files and tests that pin each claim (`typescript/src/rounds.ts`, `flag-bits.ts`; `python/src/packbin/_nodes.py`, `_validate.py`, `_pack.py`, `_pack_rounds.py`, `_unpack.py`; `csharp/RowRounds.cs`, `RoundScopes.cs`, `Walker.ShortLists.cs`, `Walker.StrandedCounts.cs`, `Walker.Numbers.cs`, `SchemeOrder.cs`, `Packbin.cs`; `java/.../Rounds.java`, `Presence.java`, `SchemeOrder.java`; `rust/src/field/round_body.rs`, `field/map_scheme.rs`, `walk/flag_bits.rs`; `cpp/include/packbin/order.hpp`, `cpp/src/core/pack.cpp`, `values.cpp`). The reverse-dependency step is heuristic: there is no `modules/` directory, so the component description is the lowest doc level, and the callers below were found by reading the diff, not by an analyzer. No code was run in this pass. Every byte string, error text and number in the docs comes from a report, a test or a source line read here; the suite counts (C# 1479 on both targets, TypeScript 880, Python 1003, Rust 625, Java 2153 checks, hostile cases 55) and the Cortex-M4F figures (flash 8152 of 8192 B, stack 456 of 512 B) come from `test_run_loop21_report.md` and `batch_01_loop21_report.md`, not from a run in this pass.

Callers and sourcers found by reading:

- C# `RoundScopes.Validate` (which now also runs `CheckBodies`) is called by `SchemeOrder.Walk`; `RowRounds` is built by `FieldBinding.OfRound` and asked by `SchemeOrder.RoundRow` (construction), `RowBinding.Read` and `Apply` (typed pack and unpack); `RequireNoShortOptionalLists` is called by `PackRepeat`; `RequireNoStrandedCount` by `PackFlags` and `PackFlagBit`
- C# `Walker.WholeNumber` (floats refused for integer fields) is called by the integer arm of the scalar write; `Walker.Scalars.cs` boxes each integer kind by its own type
- TypeScript `validateRoundBodies` is called by `new Scheme` (`index.ts`); `refuseShortOptional` by the `repeat` arm of `pack-fields.ts`; `refuseUnwrittenCount` by `pack-fields.ts` at the clear split bit and the clear combined-`flags` member; `overlay` by `packItem`, `sliceRound` by `packRounds`
- Python `_finish_round` is called by the `repeat` and `times` arms of the bind step; `node.width` is read by `_Budget.refuses` (unpack) and `_PackBudget.start_round` (pack); `_validate_round_bodies` by `Scheme.__init__`
- Rust `round_width` is called where a `repeat` or `times` field is built (`field/mod.rs`); `check_round_bodies` by `MapScheme::new`; `check_split_bit` (now returns whether the bit is set early) and `refuse_unwritten_count` by `pack_one`
- Java `Rounds.width` is called by `Rounds.pack*` and the two unpack loops; `Presence.requireCountWritten` by the clear-bit paths of `Presence`; the empty-body check by `SchemeOrder.bind` when the scheme is built
- C++ `present(..., skip)` is called by `any_child_present` and `pack_flag_byte`; `empty_round` by `check_shape`, so by `check_table`
- The hostile loaders of all six packages replay the fifteen new cases of `fixtures/hostile/cases.txt`

Direct refresh:

- `README.md` — refreshed because loop 21 changed what six packages pack and refuse and what C# builds and returns. Integers (the C# integer-type rule and its text), Repeat (the short optional list, the empty body, the C# unpack sentence), Flags (a new paragraph: the clear bit, the count behind a clear `when`, the late `when` in C++ and Rust), Times (the C# typed rounds of rows with the route example and its bytes), Untrusted input (a bullet for the empty round body), the loop 18 and 20 notes (four sentences made past tense), a new "Loop 21" block (one slot rule, the refused rows, C# changes, accepted differences, calling code) and the Limits list (the slot rule replaces the per-package counts, the memory note, the pack caps bullet, the open rows, the C# `Values` types)
- `components/01_csharp_package/description.md` — known limitations (lines 100, 102, 107, 109), Strict numbers, Typed rounds, the source layout, a Loop 21 changes list, a Typed rows of rounds paragraph and a loop 21 breaking-changes list. Changed by AZ-2373, AZ-2382, AZ-2383, AZ-2384, AZ-2386, AZ-2387, AZ-2388, AZ-2389, AZ-2390, AZ-2393
- `components/02_typescript_package/description.md`, `03_python_package`, `04_rust_package`, `05_cpp_package`, `06_java_package` — each got a Loop 21 changes list and a loop 21 breaking-changes list (C++: the Loop 21 changes list only); stale sentences replaced: Python round limits (the first-round surcharge) and the `repeat`/`flags` difference, Rust `count_fields` and the pack slot width, Java `startRound`, C++ stack and flash figures and the late-`when` open item
- `components/01_csharp_package/tests.md` … `06_java_package/tests.md` — each got a Loop 21 section: the new test files or classes, the task, what each proves, the suite counts
- `module-layout.md` — a loop 21 line in each package block and the hostile fixtures block (55 cases, the fifteen new ids)
- `system-flows.md` — the pack error table (slot width, count behind a clear `when`, empty round body, short list under `flags`, float for an integer field in C#, the split-bit clear bit)
- `interaction-risks.md` — three risk rows (F33 empty round body, slot width, parity rows), mapped to AZ-2390, AZ-2381, AZ-2382 and AZ-2383 to AZ-2387. No new row goes into `_docs/00_problem/acceptance_criteria.md` (not owned by this pass)
- `architecture.md` — the pack bounds bullet (one slot rule, the memory bound, the empty round body) and the strict-number sentence
- `glossary.md` — the Repeat entry (the body must hold a member)

Checked, not changed:

- `data_model.md`, `contracts/library/pack-session.md`, `adr/*`, `diagrams/*`, `deployment/*`, `common-helpers/*`, `epics.md`, `risk_mitigations.md`, `FINAL_report.md`, `architecture_compliance_baseline.md`, earlier ripple logs — no statement about the changed behavior found by reading the diff against `grep` for `maxSlots`, `empty`, `surcharge` and `AZ-2373`
- `_docs/02_document/tests/*` — owned by another worker in this step

Open items recorded in the docs (stated, not fixed; each is an owner row in `assessment21.md` or `review21.md`, to the loop 22 handoff):

- `bits`/`packed`/`sized` count behind a clear `when` with no value packs a clear bit (`01 00 00`) in all six, while the `times` shape is refused (U11)
- C# `List<double>` for an integer `List` builds and unpacks but pack refuses its items (U12)
- Rust map form: per-name `repeat` lists given without `__repeat__` write no round (U13)
- Python keeps its equal-length rule for every `repeat` list (U14); whether `times` follows `repeat` on a short list under `flags` (U15); Java counts a nested-row group as one slot (U16)
- C++ empty-round check counts direct children only, so a single empty `when` body builds (G1); the C++ one `Late` flag refused-id corner
- Python unpack memory after the surcharge removal: the README says it is not re-measured (step 14)

Stale after this pass, in files this pass does not own:

- `_docs/02_tasks/todo/AZ-2373_*.md` — the claim of 37 failing tests (corrected in this step by the same worker, section "Loop 21 result")
- `_docs/00_problem/acceptance_criteria.md` — the interaction ACs for the three new risk rows were not promoted
