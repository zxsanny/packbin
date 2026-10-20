# Feature assessment — loop 50

loop: 50
feature: rust-nostd-core
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-20
**Implement pass**: batches 01 to 02, no implementation report file (the completeness gate and the per-feature report are written with the loop record; see `batch_01_loop50_report.md`, `batch_02_loop50_report.md`)
**Verdict**: COMPLETE — 9 covered / 9 out-of-scope for this loop (assigned to the six slices in `todo/`) / 0 gap-clear / 0 gap-unclear

Scope assessed: AZ-2749 and AZ-2751, the two slices the owner chose for loop 50 (2026-10-20). The other six slices (AZ-2752 to AZ-2757) are unclaimed specs in `todo/` with their own ACs, so their rows are assigned to them, not counted as gaps of this pass.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| R1 | relay seals a status report into 64 bytes, no allocator | covered | AZ-2749 AC-2; `nostd_flat_tests::ac2_pack_writes_the_golden_bytes_and_the_length`, `nostd_differential_tests::std_and_nostd_write_and_read_the_same_bytes_for_random_rows`; `rust/src/nostd/walk.rs` `pack` | intake |
| R2 | output buffer too small | covered | AZ-2749 AC-3; `ac3_a_short_buffer_is_buffer_full_and_nothing_goes_past_cap`; `nostd/io.rs` `Writer::put` | intake |
| R3 | untrusted bytes: empty, short, trailing | covered | AZ-2749 AC-4; `ac4_cut_and_extended_packets_give_error_kinds_only`, `ac4_a_short_read_names_the_field_and_the_bytes_needed`, `both_refuse_every_cut_extended_and_retyped_copy_of_a_packet`; `nostd/io.rs` `Reader`, `nostd/walk.rs` `unpack` | intake |
| R5 | scheme invalid at construction | covered | AZ-2749 AC-5; `ac5_an_invalid_scheme_is_refused_before_any_byte_moves`; `nostd/scheme.rs` `validate` | intake |
| R11 | default features: whole suite and ring unchanged | covered | AZ-2749 AC-7; `cargo test` 789 passed before the last two library edits, rerun in step 11 with the ring; `rust/src/lib.rs` gates | intake |
| R12 | NaN bits, 64-bit field, 32-bit device | covered | AZ-2749 AC-6 `ac6_numbers_keep_their_bits_and_byte_order_follows_the_field`; AZ-2751 AC-1 target `rust-m4f` (`GOLDEN_OK 1` under QEMU); `nostd/row.rs`, `rust/embedded/probe/src/lib.rs` | intake |
| R13 | build over the owner's size limits | covered | AZ-2751 AC-3; `rust/embedded/checks.test.sh` (`within`, `limit_of`), a run with limits 2,655 and 87 fails naming the figure and the limit (smoke step); `rust/embedded/target.sh` | intake |
| D1 | a row refuses a value on unpack (`set_num`, `set_bytes` false) | covered | AZ-2749 `Row` contract; `a_row_that_refuses_a_value_on_unpack_is_bad_value_at_the_field` (added after batch 1); `nostd/walk.rs` `unpack_field` | batch_01 discoveries |
| D2 | the panic and heap link checks catch real defects | covered | AZ-2751 AC-4, AC-5; target `rust-mutants` (seeded `table[input]` and `Vec` through malloc); the check also found three panic paths in AZ-2749 (fixed) | batch_02 discoveries |
| R4 | hostile corpus | out-of-scope | planned in AZ-2757 AC-1 (`todo/`) | intake |
| R6 | string longer than the scratch | out-of-scope | planned in AZ-2754 AC-2 | intake |
| R7 | `text` off | out-of-scope | planned in AZ-2754 AC-3 | intake |
| R8 | `ecc` off, parity scheme | out-of-scope | planned in AZ-2755 AC-3 | intake |
| R9 | protected message repaired / too long | out-of-scope | planned in AZ-2755 AC-1, AC-2 | intake |
| R10 | session seal and open, caller nonce | out-of-scope | planned in AZ-2756 AC-1 | intake |
| D3 | flags byte of the golden packet is read as `u8` | out-of-scope | AZ-2752 (flags, bits, when) reads it as `flags`; the test comment says so | batch_01 discoveries |
| D4 | `cargo package` says the `readme` file is missing | out-of-scope | AZ-2757 AC-3 (publish dry-run) | batch_02 discoveries |
| D5 | the `embedded-arm` job grows by the Rust install, build and stage | out-of-scope | measured from the annotations after the push; the loop 51 handoff carries the figure | batch_02 discoveries |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

- A target other than Cortex-M4F (ESP32 has no stable Rust target on this host; meshbell builds it).
- Two threads sealing with one session (the session slice, AZ-2756).

### Harness gaps

- No `implementation_report_rust-nostd-core_loop50.md` yet: written with the loop record, once step 11 has run.
