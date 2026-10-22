# Acceptance criteria — loop 59

Baseline (loop 58 close): Cortex-M4F flash 8,032 B (pin 8032, budget 8,192 B), stack figures unchanged since loop 57; the shared hostile corpora pass in all eight packages.

## Rust corpus count rule

- **AC-1** `listed_inputs` counts a corpus line as an input when it has exactly three whitespace fields, the first matches `[a-z0-9_]+`, and the last is hex digits; it holds no `is_empty` check. On the real `corpus.txt` it returns the loader's count (33).
- **AC-2** A copy of `corpus.txt` with a three-field comment line whose last token is hex (`# note abcd`) does not change the count and the test passes; a copy with one extra input line raises both counts by one and passes.
- **AC-3** A loader copy whose filter also drops lines starting with a letter still makes the test fail naming the expected and loaded counts (the loop 58 check stays).

## C++ dict key order test

- **AC-4** `put_key` refuses a key longer than the key's capacity: a call with `n > sizeof(key.data)` fails the test with its own message and copies nothing.
- **AC-5** The pack helper returns the `Error`; each of the 7 pairs asserts its own result and message at its call site (`Error::Ok` for the ordered pairs, `Error::BadValue` for the refused ones), so a wrong result names that pair and line.
- **AC-6** Shown with a scratch copy that flips one pair's expectation: the failure names that pair's message. On the real tree the test passes on the Mac host and in `gcc:16`; no file under `cpp/src` or `cpp/include` changes; the arm figures stay (flash 8,032 B, stacks).

## Out of scope

`pack_children` `held_of`, the `Field` layout change, the flag-byte chain inside a `times` round, session stack and `session_core` clippy items of loop 53, size limits for the Rust feature sets, CS-D5, the first `v*` and `go/v*` tags, F44, the epic AZ-2750, row U24, a `-` placeholder in `corpus.txt`, and the other packages' loaders.

## Inherited project ACs

| Project AC | Why this loop exercises it |
|-----------|----------------------------|
| dict keys strictly ascending by unsigned bytes (AZ-2713) | AC-5 |
| hostile corpora behave the same in all eight packages | AC-1 to AC-3 |
| flash budget 8,192 B and stack budget 512 B on Cortex-M4F | AC-6 (unchanged) |
