# Acceptance criteria — loop 56

## Flash saving

- **AC-1** After the saving and before the fold, the Cortex-M4F flash image is at most 8040 B (margin at least 152 B; 8120 B today).
- **AC-2** `reads_flag_byte` no longer scans a `when`'s entries at unpack time: the answer is read from a bit set once at resolve time (or an equal change that removes the per-call scan).

## One path for held whens

- **AC-3** The `When` and `FlagBit` handling exists in one function; `unpack_one` and `unpack_children` call it and neither repeats it. If the flash does not allow it, the fold is not made and the record says why with the byte figures.
- **AC-4** After the fold, the flash image is at most 8120 B (no more than today) and the stack of the 3-deep `when` chain (504 B) and of the chain of `when`s with flag bytes (500 B) does not grow.
- **AC-5** The stack of a 3-deep `when` chain reached through a `times` round is measured on the arm image and written to `AGENT_GOTCHAS.md`; it is at most 512 B or a ticket is opened with the figure.
- **AC-6** Packets are unchanged: `make -C cpp test` on the host, `gcc:16` `make test`, the arm embedded stage, and the shared hostile corpus all pass with no new skip.

## Derived counts

- **AC-7** The Go, Swift and Rust loaders take the number of cases from `fixtures/hostile/cases.txt` (non-comment, non-empty lines); no literal 75 or 17 remains as a count assertion.
- **AC-8** Each loader still fails when a case id in `cases.txt` has no handler, and when a handler has no case: shown with a broken copy of the file (one line added, one removed) for each of the three loaders.
- **AC-9** The Go, Swift and Rust suites pass.
