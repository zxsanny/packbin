# Feature assessment — loop 55

loop: 55
feature: when-chain-and-speed-headroom
rounds: 2
verdict: COMPLETE
report_of_round: 2

## Round 1

**Date**: 2026-10-21
**Implement pass**: batch 01, `_docs/03_implementation/batch_01_loop55_report.md`
**Verdict**: EXTEND — 12 covered / 1 out-of-scope / 1 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| A1 | source three `when`s deep, all true | covered | AC-A3; `when_chain_host_tests.cpp`, image row `5b0101010105`, `CHAIN_FAILURES 0` on M4F; `pack_children`, `unpack_children` | intake |
| A2 | outermost false, or an inner one false | covered | AC-A3; rows `5b00`, `5b0100`, `5b010100`; same code path | intake |
| A3 | the chain image on the Cortex-M4F | covered | AC-A1, AC-A2; arm stage PASS: stack 504 B (chain rows 348 B pack, 292 B unpack), flash 8,040 B | intake |
| A4 | the chain exceeds 512 B | covered | AC-A4; first measure 780 B, fixed by the flat loop with packets unchanged | intake |
| A5 | AVR and `PACKBIN_NO_TEXT` builds with the chain | covered | AC-A2; avr 15,556 B of 32,256, no-text 8,040 B (margin 152 B) | intake |
| B1 | bool source in a false `when`, true in the row | covered | AC-B1; corpus `pack_when_of_skipped_bool_source` in eight packages (`0100`) | intake |
| B2 | bool source written, true / false | covered | AC-B2; `..._held_bool_source`, `..._clear` in eight packages | intake |
| B3 | empty group (presence bit) as the source | covered | AC-B3; Rust `when_bool_source_tests.rs`, C++ `when_group_source_host_tests.cpp` | intake |
| B4 | the other six packages with an empty-group source | out-of-scope | scenarios.md B4: "out of the corpus: they refuse it at construction (existing rule, not changed)" | intake |
| D1 | the 65,535 x 200 case in Go and Swift | covered | AC-D1, AC-D2; `go/text_repeat_speed_test.go`, `TextRepeatSpeedTests.swift` (0.02 s, 0.011 s) | intake |
| D2 | a package above half its bound | covered | AC-D3; none above half (worst 0.25 s, C# first call under load) | intake |
| D3 | CI runner slower than this Mac | covered | AC-D2, AC-D4; local figures in the batch report; the CI read follows the push (loop record) | intake |
| D4 | closing row U24, session stack, nostd ring driver | deferred (owner decides separately) | scenarios.md D4; stays deferred | intake |
| E1 | a chain of `when`s whose bodies each read a flag byte | gap-clear | quote: AZ-3132 Outcome "The chain figure is measured, written down, and at most 512 B." and `unpack_children` keeps a held `when` with a flag byte on `unpack_one` (batch_01 discoveries #1) → Given three nested held `when`s each holding a flag byte, When the arm stage measures unpack, Then stack is at most 512 B or the figure is recorded and the owner told | batch_01 discoveries #1 |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| E1 | Given `u8 m; when(m==1){ flag byte with a bit; when(k1==1){ flag byte with a bit; ... } }` three levels deep, When packed and unpacked in C++ and Python and measured on the Cortex-M4F image, Then packets are byte-equal, stack is at most 512 B, and the figure is in `AGENT_GOTCHAS.md` | AZ-3132 Outcome, quoted above | new task AZ-3141 (C++ only, 2 points) |

## Not walked

- The empty-group source in the Rust no-heap core (the bool cases run there through the hostile replay; the empty-group variant is tested in the std Rust tests only).
- A `when` chain with a `repeat` or `times` body between the levels (rounds restart the scope; the loop-54 AC-W8 byte-identity check covers it).

## Round 2

**Date**: 2026-10-21
**Implement pass**: batch 02, AZ-3141 (`_docs/03_implementation/batch_01_loop55_report.md` § Batch 02)
**Verdict**: COMPLETE — 1 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| E1 | a chain of `when`s whose bodies each read a flag byte | covered | AC-E1 (AZ-3141 AC-1 to AC-3); `when_chain_host_tests.cpp` `az3141_flag_chain_rows_equal_python`, image `FlagChainRow` 0x5c, `FLAG_CHAIN_FAILURES 0` on M3, M4F, s390x; arm stage: 500 B net unpack, deepest 504 B; `unpack_children`, `with_outer_flags` | assess-round-1 |

New candidates (listed, not gaps): a held `when` or flag bit reached through `unpack_table` or a `times` round still recurses through `unpack_one`; no AC names it and a `times` round restarts the chain per round. Carried to handoff 56.
