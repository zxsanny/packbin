# Feature assessment — loop 57

loop: 57
feature: flash-search-and-corpus-guards
rounds: 1
verdict: COMPLETE (gap accepted)
report_of_round: 1

## Round 1

**Date**: 2026-10-22
**Implement pass**: batch 01, `_docs/03_implementation/batch_01_loop57_report.md`
**Verdict**: CLARIFY — 11 covered / 2 out-of-scope / 0 gap-clear / 1 gap-unclear

**Owner answer (2026-10-22)**: S4 option A, accept `held_of` as the fold. S4 is `confirmed (accepted loop 57)`. Verdict after the answer: COMPLETE.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | search finds 40 B or more | covered | AC-1, AC-2 (AZ-3151); arm stage flash 8,008 B after the search (72 B saved), 8,032 B final; `keys_ascending` in `cpp/src/core/pack.cpp`; corpora and vectors 287 of 287 unchanged | intake |
| S2 | search finds less than 40 B | covered | not triggered: 72 B found; AC-1 wording kept the "report, no loosening" path | intake |
| S3 | a saving would change a refusal or a packet | covered | AC-2; the inline loop is the same order test as `memcmp` on `std::uint8_t`; host, `gcc:16`, arm stages pass, no new skip (23 skip lines both) | intake |
| S4 | the fold fits | gap-unclear | question below | batch_01 discoveries |
| S5 | the fold does not fit | covered | AC-4 (AZ-3152); try A (`unpack_range`) 7,976 B flash but flag chain 580 B net, restored by hand; figures in the batch report | intake |
| S6 | `cases.txt` copy loses the only line of a Rust unpack or limit handler | covered | AC-6 (AZ-3153); broken copy output names `negative_count` and `times_rounds_over_limit`; `rust/src/hostile_tests.rs` `unused_handlers`, `schemes.rs` tables | intake |
| S7 | a Rust nostd case moves between run and skip | covered | AC-7; broken copy output names `negative_count` (run to skip) and `construct_empty_round_body_list_element` (skip to run); `nostd_hostile_tests.rs` `SKIPS` | intake |
| S8 | `corpus.txt` copy gains a line | covered | AC-8; 34-line copy passes in Swift and Rust nostd; a malformed line fails Swift (`lists 35 inputs, the loader read 34`) | intake |
| S9 | Go id comparison with a missing and an unused handler | covered | AC-9; one `idDifference`, old messages in the broken copy | intake |
| S10 | a later edit raises the flash above the pin | covered | AC-10 (AZ-3154); `flash_pin=8032` in `lib.sh`, check in `arm.sh`; copy with 8,031 B fails with both figures | intake |
| S11 | host under load or Docker slow | covered | AC-3; one arm stage run per candidate set (worker report) | intake |
| X1 | other five packages' loaders | out-of-scope | scenarios.md X1 | intake |
| X2 | flag-byte chain inside a `times` round | out-of-scope | scenarios.md X2 | intake |

### Gaps that need a decision (gap-unclear)

#### S4: is "one decision function" the fold?

**What is not decided**
The first spec line asked that the held-`when` handling be "one function that `unpack_children` and `unpack_one` both use". What was built is one function, `held_of`, that decides what a `when` or a flag bit asks for (skip, walk inline, enter a flag scope, enter a flag-bit child). Both walkers call it, so the rule can no longer drift between them. The walkers still each contain the few lines that act on the answer (`unpack_children` in its loop, `unpack_one` in one case). A full single walker (try A) was measured: 76 B less flash, but 580 B on the flag-byte chain against 500 B allowed, so it was not kept. Both budgets hold with `held_of`: flash 8,032 B (limit 8,080 B), flag chain 476 B (limit 500 B).

**Options**
- **A — Accept as the fold**: the decision is in one place, the budgets hold, the act-on-it lines stay in two walkers. Trade-off: a change to how a held `when` is entered (not decided) still needs two edits.
- **B — One more try now**: a walker with 3 arguments (`w, i, obj`) so the tail call survives. Trade-off: another C++ worker pass and arm runs; the 8 B stack margin leaves little room.

**Recommendation**: A — it removes the drift risk of review #1 inside both budgets, and the single walker already failed once on stack.

### Gaps that are clear (gap-clear)

none
