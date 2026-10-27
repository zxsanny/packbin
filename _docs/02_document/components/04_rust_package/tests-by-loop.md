# Tests by loop (loop 19 onward): rust package

Split out of [tests.md](tests.md) in loop 23 so that file stays under the 500-line soft cap. The loop 19 to loop 22 sections below are unchanged; loop 23 is new.

## Loop 19 Tests (AZ-2329 to AZ-2338, AZ-2342)

Source: `_docs/03_implementation/batch_01_loop19_report.md`, `_docs/loops/loop19/review19.md`, `_docs/03_implementation/test_run_loop19_report.md`. The suite went from 479 to 526 (wave 1), 528 and 533 after the review fixes (436 lib tests and 97 in the other targets); clippy is clean in the touched files.

| Test file | Task | What it proves |
|-----------|------|----------------|
| `pack_round_cap_tests.rs` | AZ-2329 | `PackError::Type` for a count of 65 536, 70 000 and 4 000 000 000 in `times`, `__times_N`, a round, `flags` and a group; 65 535 packs; `with_limits(2, ..)` refuses 3 |
| `split_form_loud_tests.rs` | AZ-2331 | a clear split bit errors when a `when` source or `times` count is written after the byte and the body would be written, or the count is not written; the false condition, the combined form and a never-written source (review A2) are silent; `ac3_split_form_when_false_...` rewritten |
| `flags_member_scope_tests.rs` | AZ-2333 | each `flags` member has its own flag-byte scope; scheme S1 packs `0103030301050607` (TypeScript's bytes) and the other four rows match; S2 with no outer byte panics at construction |
| `lone_bytes_in_round_tests.rs` | AZ-2332 | a lone `Value::Bytes` in a `times` round is refused (count 1 too); `utf8` still broadcasts |
| `times_count_zero_tests.rs` | AZ-2335 | count 0 with a list or rounds errors; a lone scalar packs `0100` |
| `eq_range_tests.rs` | AZ-2338 | `U16(300)` on `u8`, `U32(70000)` on `u16`, `I16(200)` on `i8`, `I8(-1)` on `u64`, `U64::MAX` on `i64`, a `u2` slot 4 and a flag byte 256 panic at construction |
| `hostile_tests.rs` (438 lines) | AZ-2329 to AZ-2338 | the eight new hostile cases |

Existing tests changed: `az2311_ac2_...` (lone buffer), `eq(i8, U8(255))` and `eq(u64, I64(-1))`, `flags_when_member_tests.rs`, `integrity_tests.rs`, `times_lone_value_tests.rs`. File split (AZ-2342): `walk/cursor.rs` and `field/leaf.rs` moved out of `walk/unpack.rs` and `field/mod.rs`; 479 tests before and after.

## Loop 20 Tests (AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2365, AZ-2367)

Source: `_docs/03_implementation/batch_01_loop20_report.md` to `batch_04_loop20_report.md`, `_docs/loops/loop20/review20.md`, `_docs/03_implementation/reference_loop20_budget.md`, and the scenario mapping in `_docs/02_document/tests/blackbox-tests-13-loop20-pack-budget-and-parity.md` (FT-X-38 to FT-X-52). The library tests went from 436 to 469 (wave 1b), and the whole suite from 533 to 566 and 569 after the review fix pass: 472 lib tests plus 97 in the integration binaries. The AZ-2354 rows that need a `times` or `repeat` in a list element have no Rust equivalent (construction refuses it).

| Test file | Task | What it proves |
|-----------|------|----------------|
| `pack_output_budget_tests.rs` | AZ-2354 | `ac1_row1_a_lone_utf8_under_a_capped_times_is_refused_at_once_naming_the_member`; the boundary rows 4 to 13; `ac4_row14_*` and the slot rows; `ac5_rows26_28_limits_api`, `ac5_row27_a_zero_max_bytes_is_refused` (and for the typed scheme) |
| `pack_repeat_cap_tests.rs` | AZ-2355 | `ac1_row1_*`, `ac2_row2_*`, `ac3_row3_*`, rows 4 to 9 (the list-element row 10 does not apply) |
| `loop20_parity_pins_tests.rs` | AZ-2356, AZ-2359, AZ-2360, review A4 | `az2356_ac1_*`, `az2356_ac2_*` (a lone scalar now packs `010000`, was refused), `review20_a4_the_split_form_keeps_count_zero_after_the_byte`; `az2360_ac1_*`, `review20_a4_a_skipped_count_with_a_stale_zero_is_refused_under_flags_naming_the_member` (failed on HEAD with `expected a type error, got Ok([1, 0, 0])`); `az2359_ac1_a_u8_slot_takes_only_an_integer_value` |
| `hostile_tests.rs` | AZ-2367 | a `PACK_NOT_RUN` table (the list-element case is skipped with its reason); 491 lines |
| `scheme/bound_collections.rs` | AZ-2365 | not a test file: split out of `scheme/bound.rs` (514 to 357 lines); the suite is unchanged by the move |

Slow tests: the AC-4 slot rows take about 20 s in a debug build (rows 14 and 15 measured 8.5 s and 17.7 s; 0.8 s in release) and the hostile slots case 8.1 s in debug; kept at spec size (review A9). Decide with the total run whether CI should use a release build or smaller limits.

## Loop 21 Tests (AZ-2382, AZ-2384, AZ-2385, AZ-2386, AZ-2387, AZ-2390, AZ-2392, AZ-2394)

Source: `_docs/03_implementation/batch_01_loop21_report.md`, `test_run_loop21_report.md`, `reference_loop21_slots.md`. The suite went from 569 to 625 tests (step 11 container run); 22 of the 49 new tests failed on a `git archive HEAD` copy of the sources before the change.

Test files: `rust/tests/round_slot_width_tests.rs` (AZ-2382: rows 1 to 14), `empty_round_body_tests.rs` (AZ-2390: rows 15 to 26 that a map scheme can express), `late_when_in_bit_body_tests.rs` (AZ-2385), `loop21_parity_probes_tests.rs` (AZ-2384, AZ-2386, AZ-2387 pins) and `count_behind_clear_when_tests.rs` (AZ-2386, AZ-2387: rows 44 to 56), `src/hostile_tests/refusals.rs` and `src/hostile_tests/pack_cases.rs` (AZ-2392, AZ-2394; `hostile_tests.rs` shrank by the split). Changed: `pack_output_budget_tests.rs` and `scope_tests.rs` (the narrower width).

## Loop 22 Tests (AZ-2410, AZ-2412, AZ-2414, AZ-2415, AZ-2417, AZ-2418)

Source: `_docs/03_implementation/batch_01_loop22_report.md`. The suite is 489 lib and integration tests.

Test files: `tests/loop22_parity_tests.rs` (AZ-2410 rows 56 to 56d, AZ-2414 rows A1 to A11 and shape B, AZ-2415 default and the 64-slot-round packet), `repeat_lists_without_groups_tests.rs` (AZ-2412: refusals and unchanged rows), `times_tests.rs` and `times_longer_tests.rs` (three "under a flags member is refused" pins replaced by decision; a longer list still refused), `tests/count_behind_clear_when_tests.rs`, `tests/loop21_parity_probes_tests.rs`, `tests/round_limits_tests.rs` and `pack_output_budget_tests.rs` (numbers), `hostile_tests.rs` with `hostile_tests/pack_cases.rs` and `hostile_tests/refusals.rs` (AZ-2417; AZ-2418 four tests: wrong pack entry, wrong construct entry, entry for a case that is not refused, refused case without entry). Scenarios FT-X-66, FT-X-68, FT-X-70, FT-X-71, FT-X-73, FT-X-74.

## Loop 23 Tests (AZ-2433, AZ-2435, AZ-2436; review fixes G5, G6)

- `tests/repeat_dropped_values_tests.rs` (AZ-2433, U22, FT-X-78): `ac1_*` (five), `ac2_*` (two), `ac3_*` (two); review fixes in `807e718`: `g5_a_flags_name_without_groups_or_beside_groups_is_refused`, `g6_a_nested_times_key_without_groups_or_beside_groups_is_refused`, `g5_g6_groups_only_empty_values_and_a_key_the_rounds_hold_pack_as_at_head`.
- `tests/raised_slot_limit_tests.rs` (AZ-2435, G1, FT-X-80): `ac1_with_max_slots_raised_to_4_194_304_the_old_worst_packet_unpacks`, `ac2_the_default_limits_refuse_the_same_packet_at_the_slot_limit`.
- `tests/no_value_count_nested_tests.rs` (AZ-2436, G3, FT-X-81): `ac1_to_ac3_count_3_and_no_value_is_refused_in_every_nested_position`, `ac4_count_zero_count_left_out_and_a_holding_when_pack_as_at_head`, `observed_a_member_inside_a_clear_when_is_skipped_without_a_word`.
- Suite: 670 at the batch, 673 after the review fixes (489 lib and integration at loop 22 per that batch report).

## Loop 24 (Go joins the ring; no Rust test change)

Loop 24 added the Go package (AZ-2222, `components/07_go_package/`). No Rust source or test changed (batch report: the six suites have no source change). What is new for this package is its place in the ring: Go joins `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session`, `roundflags` and `roundwhen` both ways (Rust is not in the list and dict rings) (the `session` ring kind was retired in loop 74, ADR 009), through `language-pair.sh` (114 Go lines in all, guarded by `ring-wiring.test.sh`; scenario FT-X-90). The hostile case file is unchanged at 65 cases and is now read by seven loaders (FT-X-87). `walk/flag_bits.rs` was read for the U6 row.

## Loop 74: the stream session is removed (AZ-3284, AZ-3289, ADR 009)

Source: `_docs/03_implementation/batch_02_loop74_report.md` (AZ-3284), `batch_03_loop74_report.md` (AZ-3289). The stream session tests are retired (deleted), the mixed files keep their non-session tests, and the frame and crypto rows did not move.

| Test | Task | What changed |
|------|------|--------------|
| `tests/session_tests.rs` (AZ-2105), `src/session_hostile_tests.rs` (AZ-2114), `tests/nostd_session_tests.rs` (AZ-2756), `rust/embedded/probe/src/session_extra.rs` | AZ-3284 | retired with the `session` feature: deleted |
| `tests/ecc_session_dispatch_tests.rs` renamed `tests/ecc_dispatch_tests.rs` (16 to 8), `tests/times_shapes_tests.rs` (11 to 9), `src/frame_hostile_tests.rs` (8 to 6, the 2 `session`-gated tests out) | AZ-3284 | the non-session tests stay |
| `src/crypto_vectors_tests.rs` | AZ-3284 | 27 of 27 rows in the default `cargo test` (`session_core` builds with `frame` or for the std tests) |
| `src/frame_core_tests.rs`, `src/frame_hostile_tests.rs`, `tests/frame_vectors_tests.rs`, `rust/embedded/probe/src/frame_extra.rs`, the module doc example | AZ-3289 | written with the D1 names (`FrameSession`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`); 157 of 157 frame rows; the embedded figures did not move |

Suite (AZ-3284): the CI step list in the `rust` compose service, 11 steps, 912 passed, 0 failed, 1 ignored; default `cargo test` 832 to 809; `cargo build --features session` is refused. `rust/embedded/run.sh host`: no `session` set, every figure equal to the commit before (Cortex-M4F `frame` 20,332 B / 1,728 B, M33F 20,404 B / 1,728 B). AZ-3289: `run-suite.sh rust` on the host exit 0, 0 failed, 1 ignored; `cargo doc --features frame` lists the ten D1 names and none of the old six (no aliases); `rust/embedded/run.sh host` every SIZE line equal and `rust-mutants` PASS; the module doc test is the README Rust example, and `scripts/frame/readme-examples.sh` checks it (PASS Rust).
