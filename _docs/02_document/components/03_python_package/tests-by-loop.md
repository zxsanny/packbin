# Tests by loop (loop 19 onward): python package

Split out of [tests.md](tests.md) in loop 23 so that file stays under the 500-line soft cap. The loop 19 to loop 22 sections below are unchanged; loop 23 is new.

## Loop 19 Tests (AZ-2329 to AZ-2338)

Source: `_docs/03_implementation/batch_01_loop19_report.md`, `_docs/loops/loop19/review19.md`, `_docs/03_implementation/test_run_loop19_report.md`. The suite went from 692 to 764 (wave 1), 765 (the split-form rule follow-up), 773 (hostile loaders) and 777 after the review fixes, in a Python 3.12 venv (the package needs 3.10+).

| Test file | Task | What it proves |
|-----------|------|----------------|
| `test_round_fresh_scope.py` | AZ-2330 | a round starts with a fresh scope in pack and unpack; the shape that raised `TypeError` packs `010201050700`, like TypeScript |
| `test_pack_round_count_cap.py` | AZ-2329 | a `times` count of 65 536 or 4 000 000 000 raises `ValueError` (`times 1: 65536 rounds, the limit is 65535`); `with_limits(max_rounds=70_000)` packs 70 000 |
| `test_split_form_pack_fails_loudly.py` | AZ-2331 | a clear split bit raises when a `when` source is written after the byte and now matches, or a `times` count is skipped or written after the byte with values given; every unwritten source of a bit is re-checked (review B5); the false condition and the combined form stay as before, and a skipped count with values raises in `flags` too |
| `test_lone_bytes_in_round_refused.py` | AZ-2332 | a lone `bytes`, `bytearray` or `memoryview` in a `times`, `sized` or `repeat` round raises `TypeError` |
| `test_times_count_zero_with_values.py` | AZ-2335 | a list with count 0 raises; a lone scalar packs `0100`, also inside `flags` |
| `test_eq_value_checked.py` | AZ-2338 | out-of-range, `"x"`, `NaN`, `1.5`, `5.0`, `None`, a list and `True` or `False` are refused at construction; 0, 5, 255, `i8` -128, `u64` 2**64-1 and a `u2` slot 3 build |
| `hostile_support.py`, `test_bool_placement.py` | AZ-2329 to AZ-2338 | the eight new hostile cases (`pack_lone_bytes_in_round` raises `TypeError`, the others `ValueError`) |

Existing tests rewritten: `test_times_short_list.py` (three, the bare `IndexError` is now a named `ValueError`), `test_times_longer_list.py`, `test_lone_dict_in_round.py`, `test_flags_round_member.py`. A 20 000-case unpack-then-repack differential against a copy of HEAD showed equal `repeat` and `times` repack counts; the schemes whose source sits after the byte turned silent mismatches into `ValueError`.

## Loop 20 Tests (AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2362, AZ-2367)

Source: `_docs/03_implementation/batch_01_loop20_report.md` to `batch_04_loop20_report.md`, `_docs/loops/loop20/review20.md`, `_docs/03_implementation/reference_loop20_budget.md`, and the scenario mapping in `_docs/02_document/tests/blackbox-tests-13-loop20-pack-budget-and-parity.md` (FT-X-38 to FT-X-52). The suite went from 777 to 835 (wave 1b) and 846 after the review fix pass; the hostile vector tests are 34 of 34 (27 before).

| Test file | Task | What it proves |
|-----------|------|----------------|
| `test_pack_output_budget.py` | AZ-2354 | `test_ac1_row1_a_lone_utf8_under_a_capped_times_is_refused_naming_the_member` and the under-1-s, under-256-MB child-process check; `test_ac2_row2_*`, `test_ac3_row4_*` to `row13_*`, `test_ac4_row14_*` to `row16_*` (row 16 pins `ShortPacket(field='1', needed=0, left=66040)`, review B3), `test_order_row17_*` to `row21_*`, `test_scope_*`, `test_width_*`; `test_ac5_row27_an_invalid_max_bytes_is_refused_like_the_other_limits` |
| `test_pack_repeat_round_cap.py` | AZ-2355 | `test_ac1_row1_*`, `test_ac2_row2_*`, `test_ac3_row3_*`, `test_row4_*` to `test_row10_*` |
| `test_loop20_parity_pins.py` | AZ-2356, AZ-2359, AZ-2360, AZ-2362, review B1 | `test_az2356_ac1_*` (a list is refused), `test_az2356_ac2_*` (a lone scalar now packs `010000`); `test_az2360_ac1_combined_flags_skipped_count_with_values_is_refused_naming_the_member`; `test_az2362_a_repeat_with_an_empty_list_as_a_flags_member_leaves_the_bit_clear`; `test_review_b1_*` (a required leaf with an empty list is `KeyError` `'missing field w'`, never a bare `IndexError`); `test_az2359_ac1_an_int_enum_member_packs_as_its_integer` and the plain `Enum` refusal |
| `test_split_form_pack_fails_loudly.py`, `test_pack_round_count_cap.py`, `test_times_short_list.py`, `test_flags_round_member.py` | AZ-2360, AZ-2354 | the message now names `pt` and the `times` cap text follows the reference (`x: the times count is 65536, above the limit of 65535 rounds`) |
| `hostile_support.py` | AZ-2367 | the seven new hostile `pack` cases |

Slow tests: the suite is about 20 s slower (25.7 s); the hostile element case 7.1 s and the slots case 3.3 to 4.2 s are kept at spec size; `test_nfr_round_trips` (in `test_position.py`, bound 2 s) measured 0.83 to 0.87 s against 0.70 to 0.78 s before the budget code, far inside its bound.

## Loop 21 Tests (AZ-2381, AZ-2382, AZ-2383, AZ-2384, AZ-2386, AZ-2387, AZ-2390, AZ-2392, AZ-2394)

Source: `_docs/03_implementation/batch_01_loop21_report.md`, `test_run_loop21_report.md`, `reference_loop21_slots.md`. The suite went from 846 to 1003 tests (step 11 container run on python:3.14, 1003 passed in 31.5 s).

Test files: `test_round_slot_width.py` (AZ-2381, AZ-2382: rows 1 to 14, pack at `max_slots` unpacks), `test_empty_round_body.py` (AZ-2390: rows 15 to 26), `test_repeat_short_optional.py` (AZ-2383: rows 27 to 39; pins the Python differences: a lone value and a short required list keep `repeat fields must have equal lengths`, a `when` list outside `flags` too), `test_loop21_parity_probes.py` (AZ-2384, AZ-2386, AZ-2387: rows 40 to 56), `hostile_refusals.py` with `hostile_loop21_support.py` and `test_hostile_vectors.py` (AZ-2392, AZ-2394: the rule table and the 15 new cases, 55 in all). Changed: `test_round_limits.py` (the first round of a run now costs one slot per name, not nine), `test_pack_output_budget.py` and `test_times_short_list.py`. Not re-measured: the Python unpack memory figures.

## Loop 22 Tests (AZ-2410, AZ-2413, AZ-2415, AZ-2417, AZ-2418)

Source: `_docs/03_implementation/batch_01_loop22_report.md`. The suite went from 1003 to 1099 tests.

Test files: `test_loop22_parity.py` (AZ-2410 rows 56 to 56d and plain, AZ-2413 rows R1 to R3 and the unpack round trip, AZ-2415 F10 packet refused by the slots), `test_shared_count_node.py` (a counted node shared by two schemes keeps each scheme's count source), `test_repeat_short_optional.py` and `test_round_lists.py` (the equal-length pins replaced: lone value packs, short required list refused naming the member, short `when` list packs), `test_round_limits.py` and `test_pack_output_budget.py` (numbers, bytes route of the element row), `test_hostile_vectors.py` with `hostile_loop22_support.py` and `hostile_refusals.py` (AZ-2417 ten new cases; AZ-2418 four tests: wrong pack entry, wrong construct entry, control, scheme refusal of the `construct_empty_*when*` cases). Scenarios FT-X-66, FT-X-69, FT-X-71, FT-X-73, FT-X-74.

## Loop 23 Tests (AZ-2435, AZ-2436, AZ-2437)

- `test_no_value_count_nested.py` (AZ-2436, G3, FT-X-81): `test_az2436_ac1_to_ac3_a_no_value_count_above_zero_is_refused_in_nested_positions`, `test_az2436_ac4_count_zero_left_out_and_a_holding_when_pack_as_at_head`, `test_az2436_ac4_a_holding_when_with_a_value_packs_as_at_head`, `test_az2436_a_member_under_a_clear_when_inside_the_bit_is_not_reached_and_packs`, `test_az2436_ac2_observed_a_member_inside_the_clear_inner_when_is_a_silent_skip`; AZ-2437 (FT-X-82): `test_az2437_ac1_a_short_count_list_whose_missing_round_is_clear_packs`, `test_az2437_ac3_a_holding_round_with_no_count_entry_is_refused_as_at_head`.
- `test_raised_max_slots.py` (AZ-2435, G1, FT-X-80): four tests (raised limit unpacks and repacks, default refuses, one slot below the total refuses the last item); 4 to 6 s and a few hundred MB, no slow marker.
- Suite: 1476 (1099 at loop 22).

## Loop 24 (Go joins the ring; no Python test change)

Loop 24 added the Go package (AZ-2222, `components/07_go_package/`). No Python source or test changed (batch report: the six suites have no source change). What is new for this package is its place in the ring: Go joins `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session`, `listgroup`, `dictgroup` and `listflags` both ways (Python is not in the `roundflags` and `roundwhen` rings) (the `session` ring kind was retired in loop 74, ADR 009), through `language-pair.sh` (114 Go lines in all, guarded by `ring-wiring.test.sh`; scenario FT-X-90). The hostile case file is unchanged at 65 cases and is now read by seven loaders (FT-X-87). Python 3.14 in Docker was used to check the U6 row (a `times` count above 2^53) for Go.

## Loop 74: the stream session is removed (AZ-3283, ADR 009)

Source: `_docs/03_implementation/batch_01_loop74_report.md`. The stream session tests are retired (deleted), the mixed files keep their non-session tests, and the frame and crypto rows did not move.

| Test | Task | What changed |
|------|------|--------------|
| `test_session.py` (AZ-2104, AZ-2231, AZ-2244), `test_session_pad_after_type.py`, `test_session_payload_type.py` | AZ-3283 | retired with `_session.py`: deleted |
| `test_crypto_vectors.py` (new, 41 cases) | AZ-3283 | `_crypto.py` (was `_session_pad.py`) on the 27 rows (SHA-256 6, HMAC 8, HKDF 3, ChaCha20 block 6, XOR 4); 6 in-suite mutant copies each fail on exactly the changed row; 7 guard cases (key and nonce size, counter range, a stream past the last block counter, HKDF length) |
| `test_ecc_session_text_dispatch.py` renamed `test_ecc_text_dispatch.py` (79 to 71) | AZ-3283 | EC-10 out; the text dispatch tests stay |
| `test_ecc_dispatch_order.py` (6 to 4), `test_hostile_unpack.py` (16, one plain-unpack test moved in), `test_star_import.py` (5 to 7) | AZ-3283 | the duplicate-type-before-parity-mix check runs on `BinaryPacker.unpack`; no stream name is exported |

Suite: 3,793 passed, 0 failed, 0 skipped on Python 3.14 (3,877 before); `pyproject.toml` `dependencies = []`.
