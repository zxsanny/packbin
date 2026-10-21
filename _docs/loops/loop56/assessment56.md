# Feature assessment — loop 56

loop: 56
feature: held-when-one-path-and-flash
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-21
**Implement pass**: batch 01, `_docs/03_implementation/batch_01_loop56_report.md`
**Verdict**: CLARIFY — 11 covered / 1 out-of-scope / 0 gap-clear / 1 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| F1 | a `when` whose body reads no flag byte, held | covered | AC-3 (AZ-3143); `when_chain_host_tests.cpp`; `unpack_children` `holds_flag_byte()` false branch; corpus and arm stage unchanged | intake |
| F2 | a `when` whose body reads a flag byte, held | covered | AC-2, AC-3; `when_flag_bit_host_tests.cpp`, flag chain rows `5c...`; `unpack_children` flag-scope branch | intake |
| F3 | table built by host builders and by generated tables | covered | AC-2; `when_flag_bit_host_tests.cpp` compile-time and run-time build; `resolve()` in `order.hpp` (every scheme goes through `check_table`) | intake |
| F4 | flash image after the saving | gap-unclear | question below | batch_01 discoveries |
| H1 | held `when` or flag bit reached from `unpack_one` | covered | AC-1 as allowed outcome (fold not made, both paths unchanged); arm stage vectors 287 of 287 | intake |
| H2 | 3-deep chain and flag-byte chain stack | covered | AC-2 (AZ-3144); arm stage: 504 B deepest, flag chain 500 B net; `ac2_main.cpp` | intake |
| H3 | 3-deep chain through a `times` round | covered | AC-3 (AZ-3144); scheme 0x5d, 436 B net, packets equal Python; `when_chain_host_tests.cpp`, `all_kinds.cpp` | intake |
| H4 | the fold does not fit the flash | covered | AC-1 (AZ-3144); batch report: 8,140 B and 676 B net, fold restored | intake |
| H5 | AVR and `PACKBIN_NO_TEXT` builds | covered | AC-1 (AZ-3143) second clause; avr-uno 15,608 B of 32,256; no-text image 8,080 B | intake |
| C1 | `cases.txt` gains a valid line | covered | AC-2 (AZ-3145); broken copy output in the worker report: Go, Swift, Rust nostd name `brand_new_unpack_case`; loaders in `go/hostile_loader_test.go`, `HostileTests.swift`, `nostd_hostile_tests.rs` | intake |
| C2 | `cases.txt` loses a line | covered | AC-2; same broken copy, `invalid_utf8` named in Go, Swift and Rust nostd | intake |
| C3 | the Rust loader of `cases.txt` | covered | AC-1 (AZ-3145); heap-free loaders `nostd_hostile_tests.rs`, `nostd_hostile_pack_tests.rs`; `git grep` for literal counts empty | intake |
| X1 | the other five packages' loaders | out-of-scope | scenarios.md X1: "not named by the review" | intake |

### Gaps that need a decision (gap-unclear)

#### F4: flash saving 40 B short

**What is not decided**
The spec asked for a flash image of at most 8,040 B so that the fold of the two held-`when` paths would fit. The resolve-time bit saved 40 B (8,120 B to 8,080 B), so the 8,040 B target is missed. The fold, tried on top of 8,080 B, needs about 60 B more flash saved and a frame that does not grow before it can pass. Finding another 40 to 60 B in `cpp/src/core` is a search with no known answer.

**Options**
- **A — Accept and carry**: keep the 40 B saving (margin 72 B to 112 B), record the target as missed, leave the fold for a later loop that starts with the byte search. Trade-off: the duplicated held-`when` code stays for now.
- **B — One more round now**: a new task to find at least 40 B more in `cpp/src/core` and retry the fold. Trade-off: another C++ worker pass and arm-stage runs (about 3 minutes each), with no guarantee the bytes exist.

**Recommendation**: A — the saving is real and safe, and the byte search is unbounded research better framed as its own loop.

### Gaps that are clear (gap-clear)

none

### Not walked

- A flag-byte chain inside a `times` round (no AC names it; handoff 57).
