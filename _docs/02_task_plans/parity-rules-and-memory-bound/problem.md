---
loop: 22
branch: dev
---

# Loop 22 — parity rules U11 to U15, the default slot limit (U17) and the C++ empty-when body (G1)

Loop 22 (on `dev`; no worktree). Intake: `_docs/loops/loop22/handoff22.md`. Owner decisions taken 2026-10-12 ("accept all recommended"): U11 A, U12 A, U13 A, U14 A, U15 B, U16 B, U17 A. The Go package (AZ-2222) follows, so the rules it must copy are settled first.

## What

1. U11: a `bits`/`packed`/`sized` count behind a clear `when` with no value is refused in six packages (AZ-2410).
2. U12: C# integer list given double/float/decimal elements is refused at construction (AZ-2411).
3. U13: Rust refuses per-name `repeat` lists without `__repeat__` groups (AZ-2412).
4. U14: Python `repeat` lists of unequal length pack like the five (AZ-2413).
5. U15: Rust accepts a short `times` list under `flags` (AZ-2414).
6. U16: README exception only (Java counts a nested-row group as one slot, TypeScript counts members; Go copies TypeScript) — step 13, no spec.
7. U17: default `maxSlots` 1 048 576 in the five growable packages with a memory A/B (AZ-2415).
8. G1: C++ empty-`when` round body refused if the 40 B flash margin allows (AZ-2416).
9. Hostile cases (AZ-2417) and loader checks (AZ-2418).

## Decisions made while grasping

- **D1** TypeScript implements AZ-2410 and AZ-2415 first and writes `_docs/03_implementation/reference_loop22.md`; the parent checks it before the other packages start.
- **D2** AZ-2413 and AZ-2410 are probe-then-align: a worker records the outcome of the other packages before it changes code; where the five differ the worker stops (loop 19 lesson).
- **D3** U15 and U13 take the TypeScript/Python row as the reference bytes.
- **D4** AZ-2415 states a measured memory ceiling per package; a package above 400 MB is reported before the parent picks a lower value.
- **D5** AZ-2416 is flash-gated like AZ-2385: dropped and the saving written to the loop 23 handoff if the arm stage passes 8 192 B.
- **D6** Out of scope: Go (AZ-2222, next), Swift (AZ-2223), AZ-2068, tags, mypy/clippy/rustfmt clean-up, the C# ring row-round driver (waits for Go).

## Out of scope

Wire format of accepted rows; the session layer; a release or tag.

## Flagged concerns

None.
