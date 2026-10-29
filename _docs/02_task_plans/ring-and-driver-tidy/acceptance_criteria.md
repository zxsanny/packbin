# Acceptance criteria - loop 83 (ring and driver tidy)

Measured on HEAD dbf9a57. Every count is re-read on HEAD at new-task (`AGENT_GOTCHAS`).

## T1 - split handoff.cpp

- **AC-1.1** No `.cpp` file under `.github/workflows/drivers/` has more than 500 lines (`wc -l`); today `handoff.cpp` has 639.
- **AC-1.2** The C++ driver builds with `-std=c++17 -O2 -Wall -Wextra -Werror` from the sources named on the compile line of `ring-lib.sh`; 0 warnings.
- **AC-1.3** Behaviour is unchanged: `bash .github/workflows/ring-frame.sh` and `bash .github/workflows/language-pair.sh` end with the same pair counts and 0 mismatches as the run on HEAD recorded in the task spec; the C++ driver's output for every ring input is byte-identical (the 64 frame pairs include the C++ writer and reader).
- **AC-1.4** `ring-lib.sh` still compiles once per run with `|| return` on the compile, and `PACKBIN_CPP_HANDOFF` still forces a rebuild on every call.

## T2 - shared ring-wiring module

- **AC-2.1** None of the 12 duplicated definitions (`FLAGS`, `CACHE_USES`, `SHA_PIN`, `ASCII_SPACE`, `STRING_ESCAPES`, `to_s`, `inspect`, `first_set`, `dig`, `steps_of`, `code_lines`, `runs`) is defined in either checker; each is defined once in the new module under `scripts/ci/`. Lines duplicated between the two checkers fall from 52 to 0.
- **AC-2.2** `ring-wiring.test.sh`, `ring-wiring-rows.test.sh` and `ring-wiring-swift.test.sh` pass with the same label inventory and the same number of mutants and scenarios as on HEAD (counts recorded in the task spec); no check or mutant is removed, renamed to hide a loss or loosened.
- **AC-2.3** Both checkers still run as `python3 -I <checker> ...`; the message of an unreadable YAML (exit 2) and every violation text are unchanged byte for byte (a mutation run compares the output on HEAD and after).
- **AC-2.4** `publish-pins.test.sh` (no `ruby`, PyYAML install where YAML is read) still passes; if the new module is imported by a CI job that has no PyYAML install, the check named in that test still says what is missing.

## T3 - ring rows: wrong-length key or msg_id with a second refusal

- **AC-3.1** `fixtures/frame/ring-cases.txt` gains at least 14 rows: 6 refuse-seal (key33 and id7, each with `ad256`, `body256`, `outshort`) and 8 refuse-open (key33 and id7, each with `ad256`, `body256`, `clear256`, `buffer`), each expecting `BadValue`. Total refuse rows 42 -> at least 56.
- **AC-3.2** The loader derives every expected value again from `framefmt.py`: each new row is confirmed by the reference (a row it does not confirm stops the ring), and the reference answers `BadValue` for all 14.
- **AC-3.3** `bash .github/workflows/ring-frame.sh` ends with 0 mismatches over the new rows in all 8 drivers; the 6 byte-string packages answer from the package, Rust and C++ print `BadValue` by construction and the row comment says so.
- **AC-3.4** Sensitivity: in a scratch copy, a package that checks the length after the second refusal (one reordered check) makes the ring fail on at least 1 new row; the copy is discarded and nothing of it is committed.
- **AC-3.5** Every reader of the row count or of the row list (`git grep` of `ring-cases`, `ring-frame`) passes, including `ring-frame.test.sh`, `ring-frame-drivers.test.sh` and `ring-wiring-rows.test.sh`.
- **AC-3.6** If any package answers a different error first, no row is dropped or bent: the loop stops on it and reports (flagged concern).

## Loop

- **AC-L.1** `scripts/loop-tests.sh` (or the stages the touched scripts belong to) is green at host load below 60; the CI of the push is read.
- **AC-L.2** No file other than the three tasks' owned paths, `_docs/`, and what the readers force changes.
