# Acceptance criteria: pack.cpp flash saving, then pack-side `held_of`

Project ACs are inherited (wire format, error kinds, budgets of feature AC-5). Rows below are this loop's. Flash is the `size14` probe delta over `baseline` on Cortex-M4F, from `docker compose -f docker-compose.test.yml run --rm cpp-embedded`.

## Part 1: the saving

**AC-1: Baseline** — Before any source edit, the arm embedded stage is run on HEAD (`c9ceaa7`); Cortex-M4F flash (expected 7,808 B) and the pack and unpack stack figures (expected 496 B deepest) go to the loop 63 record.

**AC-2: Saving** — A kept saving brings Cortex-M4F flash to at most 7,736 B (at least 72 B under 7,808 B) for the loop to proceed to part 2. A saving of 1 to 71 B is kept when AC-3 to AC-6 hold, and part 2 is skipped. With no saving at all, the source stays at HEAD and the figures of every shape tried are recorded.

**AC-3: Stack** — Every stack figure the arm stage reports is at most its HEAD value: pack 412 B / 448 B / 500 B (plain / flag / round chain, as in the loop 61 table) and the deepest 496 B of 512 B.

**AC-4: Wire bytes and errors** — Every pack vector and cross-language byte pair stays byte-equal, and each refused input returns the same `Result` (`Error`, offset, field id) as at HEAD: `make -C cpp test` on the Mac host (after `make -C cpp clean`) and in `gcc:16` pass with 0 failures.

**AC-5: Pin** — `flash_pin` in `cpp/embedded/lib.sh` is lowered to the new figure; it is never raised.

## Part 2: pack-side `held_of` (only when AC-2 reached 72 B)

**AC-6: Candidate figures** — The loop 61 shape (patch `pack_held_of_a.patch`, shapes A to E of its table as needed) is built on the saving and its Cortex-M4F flash and stack figures are recorded next to the part 1 figures.

**AC-7: Keep rule** — `held_of` is kept only when flash is at most the part 1 figure (the new pin) and no stack figure of AC-3 grows. Otherwise it is dropped (source at the part 1 state) and the figures recorded.

**AC-8: One decision point** — If kept, `pack.cpp` decides "skip / enter inline / enter a flag bit's child" for a `when` or a flag bit in one function called by both `pack_children` and `pack_one`; no second copy of the `when_matches` / `present(i + 1)` test remains for these two kinds.

## Both parts

**AC-9: Other targets and docs** — When any source change is kept, the full arm stage (Cortex-M4F, M0, AVR Uno `cpp-avr-uno`, big-endian) passes with 0 compile warnings, and the new flash and stack figures and margins are in `_docs/AGENT_GOTCHAS.md` and the C++ description.
