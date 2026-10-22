# Acceptance criteria — loop 60

Baseline (loop 59 close): Cortex-M4F flash 8,032 B (pin 8032, budget 8,192 B), stack figures unchanged since loop 57; the shared hostile corpora pass in all eight packages; `corpus.txt` lists 33 inputs.

## C++ dict key order test

- **AC-1** The pack helper returns the `Error`; a pair that returns an unexpected `Error` fails with a message that names the pair and prints the `Error` returned and the one expected (by name).
- **AC-2** Shown with a scratch copy that flips one pair's expectation: the failure line names that pair and shows both `Error` names. On the real tree the test passes on the Mac host and in `gcc:16`.
- **AC-3** `put_key` returns whether it copied; when it refuses an oversize key (`n > sizeof(key.data)`) the pair is not packed and the helper returns an `Error` that no pair expects, so the refusal cannot pass as `Ok` or `BadValue`. Shown with a scratch copy that calls `put_key` with n = 5. No file under `cpp/src` or `cpp/include` changes; the arm figures stay (flash 8,032 B, stacks).

## Rust corpus count rule

- **AC-4** `listed_inputs` counts a line as an input when it has exactly three whitespace fields, the first and the second match `[a-z0-9_]+`, and the third is lowercase hex digits; it makes no `Vec` per line. On the real `corpus.txt` it returns the loader's count (33).
- **AC-5** Scratch copies of `corpus.txt`: a line with an upper-case hex last field, a line with a kind outside `[a-z0-9_]+`, and a `# note abcd` comment leave the count unchanged and the test passes; one extra valid input line raises both counts by one and passes. A loader copy that also drops lines starting with a letter still fails naming the expected and loaded counts.

## Out of scope

`pack_children` `held_of`, the `Field` layout change, the flag-byte chain inside a `times` round, session stack and `session_core` clippy items of loop 53, size limits for the Rust feature sets, CS-D5, the first `v*` and `go/v*` tags, F44, the epic AZ-2750, row U24, the other packages' loaders.

## Inherited project ACs

| Project AC | Why this loop exercises it |
|-----------|----------------------------|
| dict keys strictly ascending by unsigned bytes (AZ-2713) | AC-1 to AC-3 |
| hostile corpora behave the same in all eight packages | AC-4, AC-5 |
| flash budget 8,192 B and stack budget 512 B on Cortex-M4F | AC-3 (unchanged) |
