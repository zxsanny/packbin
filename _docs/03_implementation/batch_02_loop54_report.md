# Batch Report

**Batch**: 2 (loop 54)
**Tasks**: AZ-2816_cpp_when_of_skipped_source
**Date**: 2026-10-21

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2816_cpp_when_of_skipped_source | Done | C++ core 6 files (`values.cpp/.hpp`, `pack.cpp`, `order.hpp`, `table.hpp`, tests + Makefile + main.cpp), corpus 2 files, runners in 7 packages | see below | None |

## Code Review Verdict: not run per batch

Owner rule (memory `one-total-review-and-test`): one total review and one step-11 run per loop. Mutation checks below stand in.

## What changed

- `Field::bit` already linked a count source to each `when` that holds it (`mark_held`); `resolve` now does the same for the source of a `when`. `source_skipped` (moved from `pack.cpp` `count_skipped` to `values.cpp`, one definition) walks that chain; `when_matches` is false when its source is skipped. Pack and unpack both use `when_matches`, so a `when` of a skipped source is false on both sides, also for plain members where an unread source holds 0.
- Corpus: `pack_when_of_skipped_source` (`k == 2`) and `pack_when_of_skipped_source_zero` (`k == 0`), both `bytes 0100`, README sections and the loop 54 paragraph. `check-cases.sh` and `cases.test.sh` pass (72 cases).
- Runners: C++ (two handlers in `hostile_pack_loop21.hpp`; new `when_skipped_source_host_tests.cpp` with the rows of the results report, nested, same-`when`, plain members), Python, TypeScript, C#, Rust (std and no-heap core), Go, Swift, Java. Pinned case counts in the Go, Swift and Rust loaders moved from 70 to 72 (Rust nostd: 38 to 40 pack cases).

## Evidence

- Before the fix (new tests, `gcc:16`): AC-1, AC-2, both nested-skip rows failed on pack bytes (`010005`, the body written).
- Mutant (the `!source_skipped` term removed from `when_matches`): both corpus cases (`got 010005`) and seven checks of the new C++ test fail, including `AC-2 plain members ... unpack`: an unread plain source reads 0 and matches `when(k == 0)`; restored.
- C++ suite on `gcc:16`: all tests passed (also no-text and no-ecc builds, `-Werror`).
- Embedded stage (`cpp-embedded`, EXIT 0): M4F flash 7,952 B of 8,192 (was 7,920: +32 B, margin 240 B), stack 504 B of 512 (unchanged, margin 8 B); M0+, M3 QEMU (287 of 287 vectors), s390x (287 of 287), AVR Uno example 15,428 B of 32,256 (was 15,386).
- Other packages (worker reports plus my own runs): Python 3,874 passed (compose service `python`); TypeScript 2,439 of 2,439; C# 4,236 of 4,236 on both targets; Rust 823 passed (std) and the nostd hostile lines; Go `gofmt`, `vet`, `-race` clean; Swift 421 tests; Java suite green. Every package packed both cases to `0100`: no other package had the defect.

## Test Suite

Per package as above; the total run is step 11.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The unpack side of C++ matched `when(k == 0)` for an unread plain source (value 0); `Opt` sources were already absent | AZ-2816 AC-2 | fixed by the same `source_skipped` check; pinned by the plain-member test | clear |
| 2 | `mark_held` on a `when` source brings the 255-entry distance limit (`fail_at`) to schemes whose source sits more than 255 entries after its enclosing `when`; no such scheme exists in the repository | AZ-2816 constraints | none now; the limit is the one counts already have | clear |
| 3 | `source_skipped` and `when_matches` call each other (depth = number of enclosing `when`s); the M4F stack measurement did not change (504 B) | AZ-2816 AC-7 | none | clear |
| 4 | The Xcode licence on the host lapsed during the loop: `/usr/bin/python3` and `clang` refuse to run (host `swift` and `dotnet` still work) | none | owner: `sudo xcodebuild -license`; host C++ runs used `gcc:16` in Docker, Python used homebrew 3.14 | clear |

## Commit

`[AZ-2816] C++ when of a skipped source is false on pack and unpack` · `Loop: 54`

## Next Batch: All tasks complete
