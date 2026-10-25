# Feature assessment — loop 69

loop: 69
feature: rust-m33f-and-frame-mode (frame mode, Rust first; umbrella AZ-3192, epic AZ-3199)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-25
**Implement pass**: batches 01 to 04 (`80999ef`, `06206b1`, `3d9b3f9`, `af39b7f`) and the gap close of this pass, reports `_docs/03_implementation/batch_0{1..4}_loop69_report.md`
**Verdict**: COMPLETE — 14 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | first status frame sealed and opened (E1) | covered | AZ-3203 AC-1; `tests/frame_vectors_tests.rs::every_seal_open_mac_and_replay_row_matches` (rows E1.seal, E1.open); `rust/src/nostd/frame/seal.rs`; the device probe checks the E1 body (stage `frame` set) | intake |
| S2 | duplicate counter | covered | AZ-3203 AC-3; `frame_core_tests::a_duplicate_or_old_counter_runs_no_sha_and_a_fresh_valid_one_commits` (0 compressions, 0 blocks); `open_frame` checks the window before `verify` | intake |
| S3 | reordered frames inside the window | covered | AZ-3203 AC-3, AZ-3202 AC-1; fixture row `replay.seq17` and `openwin.*`; `frame_hostile_tests::random_frames_round_trip_and_the_window_follows_the_model` (5,000 steps against a model); `frame/window.rs` | intake |
| S4 | tampered frame, changed `msg_id`, `kind`, direction, epoch or key | covered | AZ-3203 AC-2; `frame_core_tests::every_single_bit_flip_and_field_change_is_a_tag_mismatch_and_writes_nothing` (E1 to E3, every bit of `ad` and body); fixture rows `tamper.*` (33 rows); `seal.rs::verify` with `ct_eq` | intake |
| S5 | key rotation, previous slot | covered | AZ-3203 AC-4; `frame_core_tests::a_session_at_b7_with_previous_a6...`; fixture rows `prev.*`; `seal.rs` second `verify` with `FrameState::previous` | intake |
| S6 | stream call on a frame session and the reverse | covered | AZ-3203 AC-8; `frame_hostile_tests::a_frame_call_on_a_stream_session...` and `a_session_that_holds_stream_state_is_not_given_frame_keys` (with `session` on); `Session::frame_state`, `load_frame_in_place` | intake |
| S7 | body 256, `ad` 256, short body, short buffer | covered | AZ-3203 AC-8, AZ-3202 AC-1; `frame_hostile_tests::refusals_leave_no_partial_output_and_hostile_input_never_panics`; fixture rows `refuse.seal.*`, `refuse.open.*` (incl. `ad256`); `seal.rs` | intake |
| S8 | epoch 0xFFFFFF and 0x1000000, direction, kind, tag_len bounds | covered | AZ-3203 AC-1; fixture rows `keys.d*.e*`, `refuse.seal.epoch1000000/tag0/tag5/tag32/kind16`; `frame_core_tests::the_key_rows_of_the_fixture_match`; `check_load`, `load_frame_in_place` | intake |
| S9 | MAC-only in parts, label and `n` bounds | covered | AZ-3203 AC-5; fixture rows `mac.*` (E4, E5, 27 length rows in 1 to 3 parts, bounds, verify); `frame_core_tests::mac_only_tags_do_not_depend_on_the_split_and_the_key_is_small`; `frame/mac.rs` | intake |
| S10 | a caller reuses a `msg_id` | out-of-scope | `AZ-3200` `### Excluded`: "Scenario S10 (a caller reusing a `msg_id`): the library cannot check it"; the bold rule is in the README, the contract and the rustdoc of `seal_frame` | intake |
| S11 | device build with `frame` on and off | covered | AZ-3204 AC-1 and AC-2; embedded stage `frame` set 19,772 B / 1,896 B, four sets identical to a run on `06206b1`, `stream_hits` check, `checks.test.sh` | intake |
| S12 | stream bytes unchanged | covered | AZ-3203 AC-7, AZ-3200 AC-3; default `cargo test` 831 passed, 0 failed (rust:1.98); `nostd_session_tests` 13 and 22 passed; the contract's stream text is unchanged; the ring runs in step 11 | intake |
| D1 | open with an `ad` of 256 bytes: the contract named the check, not the kind | covered | contract Open step 1 now says `TooLong`; fixture row `refuse.open.ad256`; Rust assertion in `refusals_leave_no_partial_output...` (added in this pass, before the matrix; code and fixture were fixed by the implement pass, not by this skill) | batch_02 discoveries |
| D2 | loading a 600-byte session by value costs 560 B of stack | covered | `Session::frame_unloaded` and `load_frame_in_place`; `frame_hostile_tests::loading_in_place_gives_the_same_frames_as_load_frame_and_replaces_the_keys`; stage stack 1,896 B | batch_03 discoveries |
| D3 | `frame` is not implied by `std` | covered | AZ-3203 `## Flagged concerns` row (accepted-risk, owner may change); README and component description state the opt-in | batch_03 discoveries |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Residual risk (not a gap in a written criterion)

- **R1**: the CI runner (Rust 1.98, Linux) reports larger flash than this Mac (cargo 1.79): loop 68 CI base 15,060 B against 14,700 B here (+2.4%), text +2.0%, ecc +4.0%, session +2.2%; stack is lower on CI. `frame` is 19,772 B here, about 20,200 B to 20,500 B on CI, against the owner's bound of 20,480 B. Read the CI figure after the push; a raise needs a line in `limits.txt` and the owner (the bound is his).
- **R2**: the cross-language ring and the full step 11 run have not run yet; the first run is the single total run of this loop.
- **R3**: frame-mode security audit (step 14 in the plan) is still to run.

### Not walked

- Several senders sharing one replay window (the contract makes the window per sender; the caller owns it).
- A frame session on the std `PackSession` type (the spec names `nostd::Session`).

### Harness gaps

- none (all four batch reports carry the discoveries table; the batch reports of this loop were written after the batches, from the commits and runs)
