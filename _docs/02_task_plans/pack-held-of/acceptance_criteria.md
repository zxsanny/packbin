# Acceptance criteria: pack side `held_of`

Project ACs are inherited (wire format, error kinds, budgets of feature AC-5). Rows below are this loop's.

## Measure

**AC-1: Baseline** — Before any source edit, the arm embedded stage is run on the loop 60 tree and its Cortex-M4F flash figure (expected 8,032 B) and the pack and unpack stack figures are written to the loop 61 record.

**AC-2: Candidate figures** — After the edit, the same stage is run and both figures are recorded next to the baseline.

## Keep only when it fits

**AC-3: Flash** — The Cortex-M4F flash figure after the edit is at most 8,032 B (the pin). If it is above, the edit is dropped (source back to HEAD) and the figures recorded; `flash_pin` changes only to a lower value, and only when the edit is kept.

**AC-4: Stack** — Every stack figure the arm stage reports (flag chain unpack 476 B, plain chain 288 B, round chain 432 B, all-kinds 504 B of 512 B) is at most its loop 57 value.

## Behavior

**AC-5: Wire bytes** — Every pack vector and every cross-language byte pair stays byte-equal: `make -C cpp test` on the Mac host and in `gcc:16` pass, and the pack side returns the same `Result` (`Error`, offset, field id) for each refused input as at HEAD.

**AC-6: One decision point** — If the edit is kept, `pack.cpp` decides "skip / enter inline / enter a flag bit's child" for a `when` or a flag bit in one function that both `pack_children` and `pack_one` call; no second copy of the `when_matches` / `present(i + 1)` test remains in `pack.cpp` for these two kinds.

**AC-7: Other targets** — If the edit is kept, the full arm stage (Cortex-M4F, M0, AVR Uno `cpp-avr-uno`, big-endian) passes with 0 compile warnings, and the C++ description margins in `docs` and `_docs/AGENT_GOTCHAS.md` carry the new figures.
