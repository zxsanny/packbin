# Tests by loop (loop 19 onward): typescript package

Split out of [tests.md](tests.md) in loop 23 so that file stays under the 500-line soft cap. The loop 19 to loop 22 sections below are unchanged; loop 23 is new.

## Loop 19 Tests (AZ-2329, AZ-2331, AZ-2332, AZ-2335, AZ-2338)

Source: `_docs/03_implementation/batch_01_loop19_report.md`, `_docs/loops/loop19/review19.md`, `_docs/03_implementation/test_run_loop19_report.md`. The suite went from 642 to 712 (wave 1), 720 (hostile loaders) and 728 after the review fixes; strict `tsc` passes.

| Test file | Task | What it proves |
|-----------|------|----------------|
| `pack-round-count-cap.test.ts` | AZ-2329 | a `times` count of 65 536 or 4 000 000 000 throws `RangeError` (`k: the times count is 65536, above the limit of 65535 rounds`), also inside `flags`; `maxRounds` 70 000 packs 70 000 |
| `split-form-loud-pack.test.ts` | AZ-2331 | a clear split bit throws when its `when` source or `times` count is written after the byte or the count was never written, also under a `when` inside the bit (review B2); the false condition (`0100025a00`), the combined `flags` form and an empty body list with a skipped count are silent |
| `lone-bytes-in-round.test.ts` | AZ-2332 | a lone `Uint8Array` or `ArrayBuffer` in a `times` (count 1 too) or `repeat` round throws; a list of buffers packs; a lone `utf8` string still goes to every round |
| `times-count-zero-with-values.test.ts` | AZ-2335 | a list with count 0 throws, in and out of `flags`; a lone scalar packs `0100` |
| `eq-value-checked.test.ts` | AZ-2338 | out-of-range, `"x"`, `NaN`, `1.5`, `true`, `1e30`, `null`, `undefined` and `[1]` are refused at construction; `5.0`, `5n` and the `u64` maximum as a `bigint` build; `2**64` on `u64` and `2**63` on `i64` are refused (review B8) |
| `hostile-cases.ts`, `hostile-pack.ts` (support) | AZ-2329 to AZ-2338 | the loaders replay the eight new hostile cases |

Existing tests rewritten (batch report: four and two): `reference-scope.test.ts` and `when-on-written-values.test.ts`, for the removed `eq(int, undefined)` and `eq(int, null)` forms (now construction errors, or a `when` that never matches an unwritten field).

## Loop 20 Tests (AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2363, AZ-2367)

Source: `_docs/03_implementation/batch_01_loop20_report.md` to `batch_04_loop20_report.md`, `_docs/loops/loop20/review20.md`, `_docs/03_implementation/reference_loop20_budget.md`, and the scenario mapping in `_docs/02_document/tests/blackbox-tests-13-loop20-pack-budget-and-parity.md` (FT-X-38 to FT-X-52). The suite went from 728 to 758 (wave 1a, 84 suites, strict `tsc` exit 0) and counts 765 in the step 11 container run (758 plus the 7 new hostile `pack` cases in `hostile.test.ts`). TypeScript is the reference package: the hex of the reference table rows is pinned here first.

| Test file | Task | What it proves |
|-----------|------|----------------|
| `pack-output-budget.test.ts` with `tests/support/lone-utf8-budget.ts` | AZ-2354 | "AC-1 a lone string under a capped times is refused naming it, in under 1 s and 256 MB" (the helper runs in a child process, asserts under 1000 ms and 256 MiB peak RSS); "AC-3 a packet of exactly maxBytes packs; one byte more is refused"; AC-4 slot rows; "AC-5 a maxBytes below 1 or not an integer is refused like the other limits" |
| `pack-repeat-round-cap.test.ts` | AZ-2355 | "AC-1 maxRounds + 1 entries are refused naming the member"; "AC-2 maxRounds entries pack in maxRounds + 1 bytes and round-trip"; the cap in `flags`, a split bit, a `when` and a list element |
| `loop20-parity-pins.test.ts` | AZ-2356, AZ-2359, AZ-2360, AZ-2363 | groups "AZ-2356 a split count of 0 written after the byte", "AZ-2360 a combined flags times whose count is skipped", "AZ-2359 a numeric enum member in a u8 slot" (packs `01c8`; a string enum is refused) and "AZ-2363 a times inside a when inside a split bit" (already refused since loop 19) |
| `split-form-loud-pack.test.ts` | AZ-2360 | one pinned row changed on purpose: `{pt: [5, 6]}` in a combined `flags` with a skipped count is now refused (it packed `0100`) |
| `hostile.test.ts`, `tests/support/hostile-pack.ts` | AZ-2367 | the seven new hostile `pack` cases; a `PACK_REFUSAL` table pins which rule fired, so a wrong-reason `RangeError` cannot pass |

Slow tests: the hostile slots case 1.45 s; the 4.26 MB packet of the AC-4 row packs in 0.86 s (2.06 s before). The suite has no other test above 2 s from this loop.

## Loop 21 Tests (AZ-2382, AZ-2383, AZ-2384, AZ-2386, AZ-2387, AZ-2390, AZ-2391, AZ-2394)

Source: `_docs/03_implementation/batch_01_loop21_report.md`, `test_run_loop21_report.md`, `reference_loop21_slots.md` (every row was produced by this package). The suite went from 765 to 880 tests (step 11 container run, 880 passed).

Test files: `round-slot-width.test.ts` (AZ-2382: rows 1 to 14, pack at `maxSlots` unpacks, one over refused at the same round), `empty-round-body.test.ts` (AZ-2390: rows 15 to 26, the F33 request shape built in a few ms, the zero-width `bytes` bodies still build), `repeat-short-optional.test.ts` (AZ-2383: rows 27 to 39), `loop21-parity-probes.test.ts` (AZ-2384 rows 40 to 43, AZ-2386 rows 44 to 52, AZ-2387 rows 53 to 56), `round-scope-cost.test.ts` (AZ-2391: timing ratio of 100 against 1 000 top-level fields for `times` and for `list`), and `support/hostile-pack.ts` with `support/hostile-cases.ts` and `hostile.test.ts` (AZ-2394: the 15 new cases, 55 in all). `round-values.test.ts` changed one row (`{a: [1, undefined], b: [5, 6]}`).

## Loop 22 Tests (AZ-2410, AZ-2415, AZ-2417, AZ-2418)

Source: `_docs/03_implementation/batch_01_loop22_report.md`, `reference_loop22.md` (every row was produced by this package). The suite went from 880 to 917 tests; strict `tsc` is clean.

Test files: `loop22-novalue-count.test.ts` (AZ-2410: three kinds, split bit and combined `flags`, bigint count, count 0 and left out, holding `when`, rows 53 to 55, bias -1), `loop22-max-slots.test.ts` with `support/unpack-memory.ts` (AZ-2415: the default, the F10 packet refused and bounded below 535 MB, the raised limit), `loop21-parity-probes.test.ts` (row 56 pin changed), `round-limits.test.ts` and `pack-output-budget.test.ts` (numbers), `hostile.test.ts` with `support/hostile-pack.ts` and `support/hostile-cases.ts` (AZ-2417 ten new cases; AZ-2418 two wrong-rule tests). Scenarios FT-X-66, FT-X-71, FT-X-73, FT-X-74.

## Loop 23 Tests (AZ-2434, AZ-2436)

- `loop23-bigint-count.test.ts` (AZ-2434, U23, FT-X-79): per kind "AC-1 a bigint count above 2^53 is refused in the split bit and the combined flags, naming member and count", "AC-2 counts that are not above 0 or not a count pack the clear bit as at HEAD", "AC-2 safe counts above 0 keep their HEAD refusal (3n, 3, 2^53 - 1 as a bigint)"; "a times behind a clear when with a bigint count above 2^53 still packs its clear bit" (U6). The 128-row Python parity grid is in the file header.
- `loop23-novalue-nested.test.ts` (AZ-2436, G3, FT-X-81): six positions x three kinds, refused rows and AC-4 rows (TypeScript gives the reference hex), and the silent skip of a member inside the clear `when` itself.
- Suite: 967 (917 at loop 22); strict `tsc` clean for `src/index.ts` (the test files are outside that check).
