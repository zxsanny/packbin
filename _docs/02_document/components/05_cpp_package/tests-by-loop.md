# Tests by loop (loop 19 onward): cpp package

Split out of [tests.md](tests.md) in loop 23 so that file stays under the 500-line soft cap. The loop 19 to loop 22 sections below are unchanged; loop 23 is new.

## Loop 19 Tests (AZ-2331, AZ-2334, AZ-2335, AZ-2338, AZ-2340)

Source: `_docs/03_implementation/batch_01_loop19_report.md`, `_docs/loops/loop19/review19.md`, `_docs/03_implementation/test_run_loop19_report.md`. gcc:16 `make test` and host clang `make test` pass; compile-fail 15 of 15 rejected; arm embedded stage `0 target(s) failed`: Cortex-M4F stack 448 of 512 B, AC-5 flash 8064 of 8192 B; M0+ and M3 QEMU 241 of 241; s390x pass. Host-only tests are listed in `cpp/tests/core/main.cpp`.

| Test file | Task | What it proves |
|-----------|------|----------------|
| `split_form_loud_host_tests.cpp` | AZ-2331 | a flag bit whose `when` source or `times` count is written after the byte, with a body given, is `BadValue` naming the member; a `times` whose count is missing from the row refuses its rounds, also in `flags`; a false condition is silent |
| `late_source_host_tests.cpp` | AZ-2331 | a source inside the bit's own body is not late (review C1: four asserts fail if the one condition is reverted); distance 255 and 256 of `mark_late` (review C9) |
| `source_kinds_host_tests.cpp` | AZ-2334 | an empty group is a `when` source for `eq(id, true)`; the id of the field after it; a same-id field wins (review C8) |
| `times_count_zero_host_tests.cpp` | AZ-2335 | count 0 with an item is `BadValue`; a lone scalar with count 0 packs `0100` |
| `eq_value_checked_host_tests.cpp`, `compile-fail/when_eq_out_of_range.cpp` | AZ-2338 | out-of-range `eq` constants are `SchemeInvalid` at run time and a compile error for a `constexpr` scheme; `eq(u8, 1.5)` and `eq(u8, true)` still build |
| `flags_when_member_host_tests.cpp` | AZ-2340 | `flags(group(flag_byte(0), flag_bit(0, x)))` with `x` set packs `01 01 01 05` |
| `hostile_host_tests.cpp`, `hostile_pack_cases.hpp` | AZ-2329 to AZ-2338 | nine of the twelve `pack` cases run; `pack_times_count_over_limit` and `pack_lone_bytes_in_round` are skipped with reasons; `pack_times_zero_with_values` has a handler |

Existing tests changed: `times_with_a_skipped_count` (in `flags_times_repeat_member_host_tests.cpp`) expects a refusal.

## Loop 20 Tests (AZ-2356, AZ-2357, AZ-2360, AZ-2364, AZ-2367)

Source: `_docs/03_implementation/batch_01_loop20_report.md` to `batch_04_loop20_report.md`, `_docs/loops/loop20/review20.md`, `_docs/03_implementation/reference_loop20_budget.md`, and the scenario mapping in `_docs/02_document/tests/blackbox-tests-13-loop20-pack-budget-and-parity.md` (FT-X-38 to FT-X-52). gcc:16 `make test` and host `make test` pass; compile-fail 15 of 15 rejected; the arm embedded stage passes: Cortex-M4F stack 448 of 512 B, flash 8160 of 8192 B (8112 before the review fix pass, margin now 32 B); 11 new tests of wave 1a and 9 checks of the review pass fail on the sources before the change. C++ has no pack budget, so AZ-2354 and AZ-2355 have no C++ row.

| Test file | Task | What it proves |
|-----------|------|----------------|
| `split_form_loud_host_tests.cpp` | AZ-2357, AZ-2360 | `count_set_behind_a_clear_when` (a plain `times` with its count behind a clear `when`, count 0, no rounds is `BadValue`; it packed `0100`); `flags_skipped_count_with_values`; `ac2_count_never_written` |
| `late_source_host_tests.cpp` | AZ-2357, AZ-2364 | `az2364_every_late_when_of_a_bit_is_refused`; `az2364_link_over_255_is_refused_at_construction`; `az2357_hold_over_255_is_refused_at_construction` |
| `held_count_nested_late_host_tests.cpp` (new, registered in `main.cpp`) | review C1, C2, C3 | `c2_count_behind_a_clear_when_is_refused` (`bits`, `packed`, `sized`), `c2_count_behind_a_true_when_is_unchanged`, `c1_late_when_in_a_when_is_refused`, `c3_times_inside_the_holding_when_has_no_limit` |
| `times_count_zero_host_tests.cpp` | AZ-2356 | `az2356_split_count_zero_after_the_byte` (a list is `BadValue`, a lone scalar packs `010000`); it passes through the late rule, not the count-0 rule (review C4, loop 21) |
| `hostile_pack_cases.hpp`, `hostile_host_tests.cpp` | AZ-2367 | two of the seven new hostile `pack` cases run (`pack_split_count_zero_after_byte_list`, `pack_flags_skipped_count_with_values`); five are skipped with reasons (caller buffer, fixed `Array`, typed row holds an `Array`) |

Slow tests: none from this loop on the host; the arm stage takes about 3 min. The flash margin is exhausted: any further edit to `cpp/src/core` or `cpp/include` needs a saving first.

## Loop 21 Tests (AZ-2385, AZ-2390, AZ-2394)

Source: `_docs/03_implementation/batch_01_loop21_report.md`, `test_run_loop21_report.md`. The host suite and the `gcc:16` container pass; the arm embedded stage passes at 8152 of 8192 B of flash and 456 of 512 B of stack.

Test files: `late_source_host_tests.cpp` (AZ-2385: a late `when` packs when another child sets the bit, and is refused when only late members hold it), `container_tests.cpp` (AZ-2390: a `repeat` or `times` with no child is `SchemeInvalid`), `hostile_host_tests.cpp`, `hostile_pack_cases.hpp` and `hostile_pack_loop21.hpp` (AZ-2394: 8 of the 15 new cases run), `times_count_zero_host_tests.cpp` (changed). The `Makefile` lists the new header as a dependency of the test binary.

## Loop 22 Tests (AZ-2410, AZ-2416, AZ-2417, AZ-2418)

Source: `_docs/03_implementation/batch_01_loop22_report.md`. The host suite and the `gcc:16` container pass; the arm embedded stage passes at 8152 of 8192 B of flash and 456 of 512 B of stack.

Test files: `times_count_zero_host_tests.cpp` (AZ-2416: `az2416_empty_when_round_body_is_refused`, `az2416_member_round_body_builds`) (moved to `empty_body_rule_host_tests.cpp` as `g2_*` in loop 23), `held_count_nested_late_host_tests.cpp` (AZ-2410: every no-value row is refused, rows 53 to 55 unchanged), `hostile_pack_loop21.hpp` (seven new skips with reasons), `hostile_host_tests.cpp` (497 lines after the split), `hostile_rule_check.hpp` and `hostile_rule_check_host_tests.cpp` (AZ-2418: the loader checks and `wrong_rule_entry_fails_the_loader`; listed in `HOST_TESTS` and as a dependency of the test binary in the `Makefile`). Scenarios FT-X-66, FT-X-72, FT-X-73, FT-X-74.

## Loop 23 Tests (AZ-2431, AZ-2432, AZ-2436)

- `tests/core/empty_body_rule_host_tests.cpp` (AZ-2431, FT-X-75, FT-X-76): `u19_negative_eq_source_is_refused_at_the_when`, `u19_any_id_out_of_range_is_refused`, `u19_pack_and_unpack_refuse_the_scheme`, `g2_empty_shapes_are_refused_by_the_body_rule`, `g2_member_shapes_pass_the_body_rule`, `g2_hostile_empty_when_vectors_reach_the_body_rule` (the AZ-2416 tests moved here from `times_count_zero_host_tests.cpp`; `hostile_host_tests.cpp` lost its `eq(-1)` helper).
- `tests/core/packed_bias_novalue_host_tests.cpp` (AZ-2432, U20, FT-X-77): `u20_bound_packed_bias_minus_one_is_the_typed_row`, `u20_unbound_packed_bias_minus_one_is_no_value`.
- `tests/core/novalue_nested_host_tests.cpp` (AZ-2436, FT-X-81): `az2436_no_value_count_below_the_top_level`, `az2436_member_inside_the_clear_when_is_a_silent_skip`.
- All three are run from `tests/core/main.cpp`. Host, `gcc:16` and s390x (241 of 241) green; arm stage 8152 of 8192 B flash, 456 of 512 B stack, unchanged.

## Loop 24 (Go joins the ring; no C++ test change)

Loop 24 added the Go package (AZ-2222, `components/07_go_package/`). No C++ source or test changed (batch report: the six suites have no source change). What is new for this package is its place in the ring: Go joins `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session`, `roundflags` and `roundwhen` both ways, built through `ring-cxx.sh` as before (C++ is not in the list and dict rings) (the `session` ring kind was retired in loop 74, ADR 009), through `language-pair.sh` (114 Go lines in all, guarded by `ring-wiring.test.sh`; scenario FT-X-90). The hostile case file is unchanged at 65 cases and is now read by seven loaders (FT-X-87).

## Loop 74: the stream session is removed (AZ-3286, ADR 009)

Source: `_docs/03_implementation/batch_02_loop74_report.md`. The stream session tests are retired (deleted), the mixed files keep their non-session tests, and the frame and crypto rows did not move.

| Test | Task | What changed |
|------|------|--------------|
| `tests/core/session_tests.cpp`, `session_host_tests.cpp`, `ecc_session_host_tests.cpp` | AZ-3286 | retired with `session.hpp`, `session.cpp` and `os_random`: deleted |
| `tests/core/crypto_vectors_host_tests.cpp` (new, host only) | AZ-3286 | the internal `src/core/crypto.cpp` on the 27 rows of `fixtures/crypto/vectors.txt` (SHA-256 and HMAC also fed in 37-byte pieces); 6 of 6 one-digit copies fail on their own row; six broken copies of `crypto.cpp` (a round constant, a rotate, the HKDF counter, the opad, two removed limits) each fail it |
| `dict_order_host_tests.cpp` (5 tests / 19 expects to 5 / 13), `no_ecc_tests.cpp` (3 / 9 to 2 / 6), `host_tests.cpp` (3 / 3 to 4 / 6: it received the core OS scan) | AZ-3286 | the non-session tests stay |

Vector runners: 268 asserted, 268 run (290 before; the deleted `session_tests.cpp` had 22). Host `make -C cpp test` and `gcc:16` exit 0, 0 warnings; Cortex-M4F 7,712 B / 540 B and M33F 25,720 B / 724 B (the pins), AVR Uno 15,402 B flash / 196 B RAM, all as before. The ESP-IDF stage was not run on the Mac (CI runs it).
