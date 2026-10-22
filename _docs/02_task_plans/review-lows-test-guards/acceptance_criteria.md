# Acceptance criteria — loop 58

Baseline (loop 57 close): Cortex-M4F flash 8,032 B (pin 8032, budget 8,192 B), stack figures unchanged since loop 57; the shared hostile corpora pass in all eight packages.

## Rust nostd corpus count

- **AC-1** The Rust nostd corpus test derives its expected input count from `fixtures/hostile/corpus.txt` by a rule other than the loader's `!trim().is_empty() && !starts_with('#')` filter (for example every raw line is classified as blank, comment, or input in the test itself), and fails naming the expected and loaded counts when they differ. Shown with a broken copy: a loader whose filter also drops lines that start with a letter makes the test fail; the unmodified loader passes.
- **AC-2** `cargo test` for `rust/tests/nostd_hostile_tests.rs` passes with no new skip; adding a line to a copy of `corpus.txt` does not fail with a count error.

## Go refusal check

- **AC-3** `TestHostileEveryRefusalPinsOneRule` fails with the message `idDifference` returns (each missing, unused or duplicate id by name), not two raw lists. Shown with a broken copy: one `pack_error` case id removed from `hostileRefusals`, and one extra id added; each failure names that id.
- **AC-4** The Go suite passes unmodified (`gofmt -l .`, `go vet ./...`, `go test -race -count=1 ./...` in `golang:1.27`).

## `keys_ascending` with a high byte

- **AC-5** A host test packs a dict whose raw string keys differ at one byte of `0x80` against `0x7f`: the ascending order (`0x7f` then `0x80`) packs, and the descending order is refused with the dict's error. A signed-`char` compare would flip both results.
- **AC-6** The same test covers a prefix pair: keys `"a"` then `"ab"` pack, `"ab"` then `"a"` is refused, and an equal pair is refused.
- **AC-7** Shown with a broken copy of `keys_ascending` (a signed compare, then a length-first compare) on a scratch copy of the tree: the new test fails for each; the unmodified source passes it. No file under `cpp/src` or `cpp/include` is changed by the loop, and the arm stage figures (flash 8,032 B, stacks) are the same.

## Out of scope

`pack_children` `held_of`, the `Field` layout change, the flag-byte chain inside a `times` round, the session stack and `session_core` clippy items of loop 53, size limits for the Rust feature sets, CS-D5, the first `v*` and `go/v*` tags, F44, the epic AZ-2750, row U24, and the other five packages' loaders.

## Inherited project ACs

| Project AC | Why this loop exercises it |
|-----------|----------------------------|
| dict keys strictly ascending by unsigned bytes (AZ-2713) | AC-5, AC-6 |
| hostile corpora behave the same in all eight packages | AC-1 to AC-4 |
| flash budget 8,192 B and stack budget 512 B on Cortex-M4F | AC-7 (unchanged) |
