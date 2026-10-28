# Acceptance criteria — ring driver number ranges and Rust test-build fixes (loop 79)

"Was" figures are read on HEAD `cb6759b` in this loop: `ring-frame.sh` (all 8 languages) prints `refusals <lang>: 38 rows, 0 mismatched` x 8 and `64 pairs, mismatched: 0`; `ring-frame-drivers.test.sh` has 44 checks; the `frame` and `text,ecc,frame` no-run builds print 3 warnings each (4 items), the default and all-features builds 1 (in 9 crates).

## Drivers and rows

- AC-1: For each of 8 out-of-range lines (direction 256 and `-1` on a seal line, tag length 256 on a seal line, kind 256 and `clear_len` 65,536 on an open line, `out_len` 65,536 on a seal line, epoch 4,294,967,296 on a mac line, `n` 256 on a verify line) each of the 8 drivers exits non-zero, prints no result line for it, and prints a message that holds the line number: 64 runs, 0 failures, in `ring-frame-drivers.test.sh`.
- AC-2: The same lines at the top of each range (direction 255, epoch 4,294,967,295, `out_len` 65,535) give, in each of the 8 drivers, `BadValue`, `BadValue` and the sealed body, exit 0: 24 runs, 0 failures. Total checks in the script: 132 (was 44).
- AC-3: With the drivers of HEAD `cb6759b` put back in a scratch copy, the new cases of AC-1 fail for at least C#, C++ and Go (direction 256 sealed instead of refused) and for Python (`-1` accepted).
- AC-4: `ring_frame.py` stops with exit 1 and names the row for a `ring-cases.txt` row with direction 256 and for one with `out_len` 65,536 (2 cases in `ring-frame.test.sh`).
- AC-5: `ring-cases.txt` holds 6 rows at the top of the ranges; `ring-frame.sh` with all 8 languages exits 0 and prints `refusals <lang>: 43 rows, 0 mismatched` for each language (38 + 5) and `64 pairs, mismatched: 0`.
- AC-6: `fixtures/frame/README.md` names the range of each of the 8 number fields (`epoch`, `dir`, `tag_len`, `kind`, `n`, `clear_len`, `out_len`, and the digits-only rule).

## Checker

- AC-7: A stand-in reader with 7 mismatched refusal rows makes `check` print 5 mismatch lines and `... and 2 more` for that reader; a pair with 6 mismatches prints 5 lines and `... and 1 more`; a reader with 5 or fewer prints no such line (3 cases in `ring-frame.test.sh`). The mismatch totals are unchanged.

## Rust

- AC-8: `cargo test --no-default-features --features frame --no-run` and `... text,ecc,frame` print 0 `warning:` lines (was 3 each); `cargo test --no-run` and `cargo test --all-features --no-run` print 0 (was 1); Rust 1.98.
- AC-9: The Rust branch of `run-suite.sh` builds all test targets with `--no-run` for the 9 sets (7 no-std sets, default, all-features); a build that fails or prints a `warning:` line fails the suite with a message naming the set. `run-suite.test.sh` checks the 9 commands and a stand-in `cargo` that prints `warning:` (exit 1, set named).
- AC-10: In a scratch copy, removing `#![cfg(feature = "std")]` from one std test file makes the new step fail on the `none` set (proof that the class of loop 76 is caught).
- AC-11: The Rust test results are unchanged: the same test counts per `cargo test` command of `run-suite.sh` as on HEAD (read in the first batch), 0 failed.

## Non-functional

- AC-12: The step 11 `rust` stage grows by no more than 60 s over its figure on HEAD at the same load (loop 78 figure 136 s; re-measured in this loop); the `ring` stage by no more than 20 s.
- AC-13: CI on `dev` and then `main` is green after the push (all jobs of `test.yml`), read with `gh run list` and job logs.
- AC-14: No source file the loop touches ends above 500 lines unless it was above before.
