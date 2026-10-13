# Ripple log — loop 23

One pass. Scope: `_docs/02_document/**` only (README, fixture README and source belong to other owners this loop). Inputs: specs AZ-2431 to AZ-2437 in `_docs/02_tasks/done/` (AZ-2433 AC-1 and AZ-2436 AC-2 as amended), `batch_01_loop23_report.md`, `_docs/loops/loop23/{review23,assessment23}.md`, commits `3c602ff` and `807e718` (review fixes G4 to G6), and the new test files they name.

Callers and sourcers found by reading:

- C++ `when()` (`fields.hpp`) marks an out-of-range `eq` id Invalid; `check_table` runs `check_shape` (body rule, `has_member`) before `resolve` (scope rule)
- Rust `lists_agree` is shared by `check_lists` (`times`) and `check_repeat_lists` (`repeat`); `collect_below`, `times_keys` and `declares` (`walk/times.rs`) feed it; `walk/pack.rs` and `walk/flag_bits.rs` `repeat_on` call the repeat check
- TypeScript `refuseUnwrittenCount` (`flag-bits.ts`) reads `MAX_SAFE` from `kinds.ts`; `validCount` and its other callers are unchanged
- Python `_RoundValues.unwritten_count` (`_pack_rounds.py`) is read only by the U11 check through `count_of` (`_pack.py`)

Direct refresh:

- `tests/blackbox-tests-16-loop23-parity-rows.md` (new, FT-X-75 to FT-X-82) and its row in `tests/blackbox-tests.md`
- `tests/traceability-matrix.md`: 33 rows (24 AC rows for AZ-2431 to AZ-2437, 9 review23/assessment23 rows: 3 Covered, 6 Open), the six loop 22 Open rows closed, summary counts; the loops 11 to 18 not-verified section moved to `tests/traceability-not-verified-loops-11-18.md` (cap)
- `tests/blackbox-tests-07-hostile-case-file.md`, `tests/blackbox-tests-15-loop22-parity-and-memory-bound.md`: loop 22 statements that loop 23 changed are labelled (C++ "by its source check", `eq(-1, ...)` builds, the typed row has no "no value", the TypeScript large bigint count, the Rust `repeat` values dropped beside groups, the moved C++ AZ-2416 tests)
- `tests/resource-limit-tests.md`: NFT-RES-LIM-04 names the Python and Rust raised-limit tests (AZ-2435)
- `components/*/description.md`: a Loop 23 changes list in all six (breaking-changes lists for C++, Rust, TypeScript, Python); stale loop 22 Open sentences labelled as closed
- `components/*/tests.md`: the loop 19 to loop 22 sections moved to a new `tests-by-loop.md` per component (cap) with a Loop 23 section added there
- `module-layout.md` (a loop 23 line per package, hostile file unchanged at 65), `system-flows.md` (count behind a clear `when`, empty round body and the C++ `eq` id, Rust `repeat` values), `interaction-risks.md` (the loop 22 Open row closed, three loop 23 rows, one Open row for loop 24), `glossary.md` (Repeat: Rust values beside groups)

Checked, not changed: `data_model.md`, `architecture.md`, `contracts/`, `adr/`, `diagrams/`, `deployment/`, `common-helpers/`, `epics.md`, `risk_mitigations.md`, `FINAL_report.md`, earlier ripple logs (historical).

Open items recorded in the docs (loop 24 handoff): U24 C++ unbound counted member skips U11; U25 C++ count and own ids wrap; U26 C# dictionary rows of a nested-row group; review23 Low 1 Python `RuntimeError`, Low 5 Rust `lists_agree` copy, Low 6 heavy AZ-2435 tests (step 11).
