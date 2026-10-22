# Acceptance criteria — loop 57

Baseline (loop 56 close): Cortex-M4F flash 8,080 B of 8,192 B (margin 112 B); stack net 504 B deepest (all-kinds row), flag-byte chain 500 B unpack / 384 B pack, plain chain 292 B / 348 B, round chain 436 B / 436 B; `cpp-avr-uno` 15,608 B.

## Flash search

- **AC-1** The Cortex-M4F flash image (the `PACKBIN_NO_TEXT` core plus the 14-entry table, budget 8,192 B) is at most 8,040 B after the search (margin at least 152 B; 8,080 B today). A smaller saving is reported with the figure and recorded as not met, never by loosening the bound.
- **AC-2** No behavior change: every packet and every refusal of the shared hostile and differential corpora is byte-identical to HEAD; `make -C cpp test` on the host, `gcc:16` `make test` and the arm embedded stage pass with no new skip; the stack figures above are not higher; `cpp-avr-uno` and the text build stay inside their margins.

## Held-`when` fold retry

- **AC-3** After AC-1, the `When` and `FlagBit` handling is tried as one function that `unpack_children` and `unpack_one` both use, with `unpack_held` inlined into `unpack_children` and no larger frame. The fold is kept only if the flash is at most 8,080 B (no more than at the start of this loop) and the stack of the 3-deep chain, the flag-byte chain and the round chain is not above 504 B, 500 B and 436 B.
- **AC-4** If the fold is not kept, the report gives the flash and stack figures of the try and the code is restored; that is an accepted outcome. A depth limit or any wire change is never part of it.
- **AC-5** Packets stay unchanged (as AC-2) whichever way AC-3 goes.

## Corpus guards

- **AC-6** The plain Rust loader of `fixtures/hostile/cases.txt` names, by case id, an unpack or limit handler that no case uses, as the Go and Swift loaders do; shown with a broken copy (one line removed from the copy's `cases.txt`).
- **AC-7** A Rust nostd case that moves from run to a reasoned skip, or back, is noticed by id: the nostd corpus test compares the skipped set with an explicit expected set of ids with reasons; shown with a broken copy.
- **AC-8** The corpus counts of Swift (`FuzzTests.swift`) and Rust nostd (`nostd_hostile_tests.rs`) are derived from the corpus file; adding a corpus line does not fail with a count error; shown with a broken copy.
- **AC-9** The Go loader has one helper for the id comparison (`idDifference` and `sameSet` merged) and fails with the same messages as before; the Go, Swift and Rust suites pass.

## Flash pin

- **AC-10** The arm embedded stage fails when the Cortex-M4F flash image is above a pinned figure (the figure recorded by this loop after AC-1 and AC-3), naming the measured and pinned bytes; a raise needs an edit of the pin and a line in `AGENT_GOTCHAS.md`. Shown by a run with the pin one byte below the measured figure on a copy.
- **AC-11** The margins (flash and stack) are written in `AGENT_GOTCHAS.md` and the C++ description from the reports.

## Out of scope

Size limits for the Rust feature sets, CS-D5, the first `v*` and `go/v*` tags, F44, the epic AZ-2750, row U24, the flag-byte chain inside a `times` round, the session stack and `session_core` clippy items of loop 53, and the other five packages' loaders.

## Inherited project ACs

| Project AC | Why this loop exercises it |
|-----------|----------------------------|
| flash budget 8,192 B and stack budget 512 B on Cortex-M4F (`cpp/embedded/lib.sh`) | AC-1, AC-3, AC-10 |
| packets identical across the eight packages (shared corpora) | AC-2, AC-5 |
