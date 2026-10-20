# Feature assessment — loop 52

loop: 52
feature: rust-nostd-core (wave B: AZ-2754, AZ-2755)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-20
**Implement pass**: batches 01..03, `_docs/03_implementation/implementation_report_rust_nostd_wave_b_loop52.md`
**Verdict**: COMPLETE — 10 covered / 2 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| R6 | string longer than the scratch | covered | AZ-2754 AC-2; `nostd_text_tests::ac2_a_string_that_needs_the_parse_and_no_scratch_is_scratch_too_small`; `nostd/text/encode.rs::encode_field` | intake |
| R7 | `text` off: wire string forwarded, string member refused | covered | AZ-2754 AC-3; `nostd_text_off_tests::*`, `nostd_text_tests::ac3_wire_strings_*`; `nostd/check.rs` (`TEXT`), `nostd/strings.rs` | intake |
| R8 | `ecc` off, parity scheme | covered | AZ-2755 AC-3; `nostd_ecc_off_tests::*`; `nostd/check.rs::parity` | intake |
| R9 | protected message with wrong bytes, above 254 | covered | AZ-2755 AC-1, AC-2; `nostd_ecc_tests::ac1_*`, `ac2_*`; `nostd/ecc.rs`, `ecc_core.rs` | intake |
| R3 | untrusted bytes with strings and dictionaries | covered | AZ-2754 AC-4; `nostd_text_tests::ac4_*`, `nostd_text_differential_tests::ac4_*`; `nostd/text/decode.rs` | intake |
| R12 | device image with text and ecc | covered | embedded stage PASS, sets `text` and `ecc` (no panic path, no heap) | intake |
| D3 | dictionaries and key order | covered | AZ-2754 AC-5; `nostd_dict_tests::*`; `nostd/strings.rs` | assess-round-1 (loop 51) |
| X1 | strings in every presence context (flags, flag bit, `when`, group, rounds, list, dict) | covered | `nostd_text_differential_tests` 20 layouts | batch_01 |
| X2 | a wire string as a list element, a flags member, under a flag bit | covered | `nostd_text_tests::ac3_wire_strings_stand_in_*` (found a wrong `list` size in the test, not in the core) | batch_01 |
| X3 | std ECC on the shared core | covered | 22 std ECC lib tests, `ecc_scheme_tests`, `ecc_session_dispatch_tests` unchanged and green | batch_03 #5 |
| D6 | stack of a nested scheme on the device | out-of-scope | AZ-2757 holds the nested probe | assess-round-1 (loop 51) |
| X4 | size limits of `text` and `ecc` | out-of-scope | owner input (handoff52 "Owner input needed") | batch_03 #10 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

- A repeat of long raw strings: the C++ memo (AZ-2742) is not ported; CPU only, caller's own row. AZ-2757 measures it.
- A dispatch over schemes with different parity (the core has no dispatch).

### Harness gaps

- Batches 1 and 2 share one commit; the batch report is one file for the wave.
