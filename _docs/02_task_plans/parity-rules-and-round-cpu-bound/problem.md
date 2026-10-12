---
loop: 21
branch: dev
---

# Loop 21 — one slot rule, parity rules U1 to U9, and the empty-round CPU bound

Loop 21 (on `dev`; no worktree). Intake: `_docs/loops/loop21/handoff21.md`. Owner decisions taken 2026-10-12 ("accept all recommended": U1 to U9 option A, U10 option B accept). The Go package (AZ-2222) follows this loop, so the rules it must copy are settled first.

## Change location

A library with no running app. The change sits in the pack and unpack walkers and scheme construction checks of `typescript/`, `python/`, `java/`, `csharp/`, `rust/`, two C++ items in `cpp/src/core` (U5, F33) under the 32 B Cortex-M4F flash margin, the hostile fixture set `fixtures/hostile/`, the four hostile loaders' test files and the README limits section (verbal, from the handoff: "decide the table above; wave 1 U1/U2 slot rule with TypeScript as the reference, U3/U4/U6/U7 parity probes then fixes, G2/G3/G4 loader and message work, AZ-2373 in `csharp/`").

## What

1. One slot-width rule for a round in all six packages (U2, TypeScript is the reference), and Python unpack charging by it (U1).
2. Parity rules: short list in an optional flags position refused (U3), split-bit `times` with an absent body packs a clear bit (U4), C++ packs a direct late `when` in a bit body if it costs no flash (U5), count 1 behind a clear `when` refused (U6), `bits`/`packed`/`sized` counts behind a clear `when` refused (U7).
3. C#: typed rounds bind to a collection of rows (U8), a dict member that cannot hold rounds refused at construction (U9), exact integer types from unpack (AZ-2373), count text / lone `byte[]` / `WithLimits` overload (G4).
4. An empty `times`/`repeat` body is refused at construction (F33); TypeScript `sliceRound` stops copying the scope per round and the README says `maxBytes` is the memory bound (F34).
5. Hostile cases for the new rules and rule/message tables in the four loaders that pin only "refused" (G2, G3).

## Who

Callers who pack rows built from requests they do not trust (CPU bound), callers who pack with one package and unpack with another (parity), the Go implementer (one rule to copy), and the package owner (single publisher).

## Decisions made while grasping (the owner can change any)

- **D1** TypeScript is the reference for AZ-2382 and AZ-2390: it writes `_docs/03_implementation/reference_loop21_slots.md` (scheme, row, slots, hex, error text); the parent checks every AC against it before the other packages start (loop 19 and 20 lesson).
- **D2** F33 is fixed by refusing an empty round body at construction (the simpler of the handoff's two options: no per-round cost, no new counter); the "charge at least 1 slot" alternative is not built.
- **D3** U3, U4, U6, U7 are probe-then-align: each worker records the probe outcome for its package in the batch report before it changes code; the changed packages are the ones the handoff names, the rest only if the probe differs.
- **D4** AZ-2385 (U5) is flash-gated: if the arm embedded stage passes 8 192 B the change is dropped and the saving needed is written to the loop 22 handoff.
- **D5** AZ-2388 (U8) follows the Rust binding (collection of rows); old typed bindings that are valid keep working.
- **D6** U10 (message and limit parity) is accepted as is: no code, a line in the upgrade notes (step 13).
- **D7** Out of scope: Go (AZ-2222, next), Swift (AZ-2223), AZ-2068 (C++ AVR), any tag, slow-test trimming, mypy/clippy/rustfmt clean-up, the traceability catch-up of loops 11 to 18 beyond step 12.

- **D8** (after the TypeScript reference, 2026-10-12) `_docs/03_implementation/reference_loop21_slots.md` is the contract for wave 1b. Refinements the reference made: AZ-2390 refuses a round body with no *member* looking through `when` and groups (a zero-width `bytes`, a flag byte and a member-less `flags` are members and still build; the hostile unpack vectors `zero_progress_repeat_*` rely on it); AZ-2383 refuses a short optional list under `flags` for `repeat` only (`times` keeps accepting it: README Times, AZ-2248); AZ-2386 refuses a count above 0 that no field wrote behind a clear `when`, in a split bit and in combined `flags`.
- **D9** Row 56 of the reference (`bits`/`packed`/`sized` count behind a clear `when`, count in the row, **no value**) packs a clear bit `010000` in TypeScript, while U6 refuses the same shape for `times`. Wave 1b matches TypeScript row 56; making the six refuse it is an open row (U11) for the loop 22 handoff, not built here.
- **D10** C++ AZ-2385 landed at 8152 B flash (margin 40 B) and 456 B stack (margin 56 B); the C++ empty-body refusal is `Error::SchemeInvalid` at construction for a `times`/`repeat` with no child; the fixture rows must accept `scheme_error` there.

## Out of scope

Wire format changes for accepted rows; the session layer; Go and Swift; a release or tag.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A scheme with an empty round body, or a row the new parity rules refuse, packs today and fails after the upgrade | upgrade notes in step 13 | accepted-risk | Medium |
| Cortex-M4F flash margin is 32 B; AZ-2385 and the C++ part of AZ-2390 may not fit | C++ worker measures; drop or defer with a recorded saving | open | Medium |
| Stack margin 64 B on Cortex-M4F; any `cpp/src/core` edit runs the arm stage | coordinator | open | Medium |
| 14 specs (42 points) across six packages in one loop | waves of disjoint directories; one total review and one total run | accepted-risk | Medium |
