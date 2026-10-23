# Acceptance criteria — loop 65

Baselines are read from runs on HEAD `d67c654` in this loop (AGENT_GOTCHAS: figures come from a run on HEAD). Rust embedded stage log: base 14,700 B / 456 B, text 26,632 B / 2,760 B, ecc 17,980 B / 760 B, session 18,404 B / 1,832 B (flash / stack), 0 failures.

## CI

- **AC-1** `.github/workflows/test.yml` has `paths-ignore: ["_docs/**"]` under `on.push`; `on.pull_request` and `on.workflow_call` are unchanged (0 lines of diff outside `on.push`). The file parses as YAML and `on.push` keeps `branches: ["**"]`.
- **AC-2** A check script run on the new file confirms AC-1 and fails (exit 1) on the old file: 2 runs, 2 expected exit codes.

## Rust size limits (`rust/embedded/limits.txt`)

- **AC-3** The rows are the measured figure on HEAD times 1.05, rounded up to the next byte: text 27,964 B flash / 2,898 B stack, ecc 18,879 B / 798 B, session 19,325 B / 1,924 B (the stage log of the loop-close commit must show each measured figure at or under its limit, 6 of 6). The base row is unchanged (16,384 B / 512 B).
- **AC-4** `checks.test.sh` reads the real `limits.txt` and `feature-sets.txt` and fails when any set of `feature-sets.txt` has no numeric flash and stack limit: 4 of 4 sets numeric; a copy of `limits.txt` with one `-` makes the check fail (1 of 1 mutant caught).
- **AC-5** A limit one byte under a measured figure fails the stage and names the set, the figure and the limit (the `PACKBIN_RUST_EMBEDDED_LIMITS` smoke the stage already has), shown for `text` flash with limit 26,631 B: exit 1.
- **AC-6** The comments of `limits.txt`, `rust/embedded/README.md` and the Rust component description state the new limits and that the owner set them on 2026-10-23 as measured + 5%.

## Flag-byte chain inside a `times` round (C++)

- **AC-7** A scheme with a 3-deep chain of `when`s, each level holding a flag byte and one flag bit, inside a `times` round (id 0x5e, two items) is in `cpp/embedded/common/all_kinds.cpp`; 4 rows pack to the Python package bytes (reference rows below) and unpack back to the row: 4 of 4 rows, 0 differences, on the host and in the arm image.
- **AC-8** The arm embedded stage reports the deepest pack and unpack stack of the new rows; both are at most 512 B (the budget). If either is above 512 B the loop reports the figure and stops: no fix, no depth limit, no wire change (owner decision).
- **AC-9** Cortex-M4F flash of the flash-budget image stays at 7,724 B (pin) — `cpp/src/core` and `cpp/include` are not edited; stack figures of the existing images (base 496 B deepest; chains 404 B / 440 B / 492 B) are unchanged.
- **AC-10** The documents record the new figure and the 16 B / new margin (C++ package description, `AGENT_GOTCHAS.md`).

## Whole loop

- **AC-11** Step 11 (`scripts/loop-tests.sh`) reports 0 failed for every stage whose inputs changed; the CI run of the loop push is read at the next loop start.
