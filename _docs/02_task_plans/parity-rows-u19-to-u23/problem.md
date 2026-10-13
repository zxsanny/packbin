---
loop: 23
branch: dev
---

# Loop 23 — parity rows U18 to U23 and gaps G1 to G3

Loop 23 (on `dev`; no worktree). Intake: `_docs/loops/loop23/handoff23.md`. Owner decisions taken 2026-10-13 ("accept all recommended"): U18 B, U19 A, U20 A, U21 A, U22 A, U23 A. None changes the wire format of an accepted row. The Go package (AZ-2222) is the next loop.

## What

1. U18 B: README exception only (Rust takes rounds as `__times_N` groups when a `when` sits inside a `times`, as for `repeat` under U13; repack from groups, not per-name lists, review22 finding 1 / F35) — step 13, no spec.
2. U19 A: C++ refuses a `when` whose `eq` names a negative source id, flash-gated; G2 pins the empty-body rule so it still fires on its own (AZ-2431).
3. U20 A: trace the C++ `packed` bias -1 refusal in the U11 grid; README exception if it is the typed row, else align, flash-gated (AZ-2432).
4. U21 A: keep the three `construct_empty_*when*` hostile cases; README text says which rule fires first per package (step 13), no spec.
5. U22 A: Rust refuses `repeat` values it would drop (lists beside `__repeat__` groups; nested round names) (AZ-2433).
6. U23 A: TypeScript refuses a bigint count above 2^53 in the U11 shape (AZ-2434).
7. G1: raised-limit unpack test in Python and Rust (AZ-2435).
8. G3: U11 refusal pinned in groups, nested holding `when`s and round bodies (AZ-2436).

## Decisions made while grasping

- **D1** One worker per package directory; `cpp/` runs AZ-2431 then AZ-2432 in one worker (both touch `order.hpp`/C++ tests and the flash budget).
- **D2** AZ-2431 and AZ-2432 are flash-gated as AZ-2416 was: if the arm stage passes 8 192 B flash or 512 B stack the source change is dropped and the saving needed goes to the loop 24 handoff.
- **D3** AZ-2436 is test-only and probe-first: a package that packs where the rule says refuse is reported to the parent, not fixed inside the task.
- **D4** No new hostile cases: U19, U20, U22 and U23 are single-package alignments pinned by package tests; the hostile set stays at 65 (U21 A).
- **D5** Out of scope: Go (AZ-2222, next), Swift (AZ-2223), AZ-2068, tags, mypy/clippy/rustfmt clean-up, review findings 10 and 11, the C# ring row-round driver, the TypeScript `times` bigint split (U6).

## Out of scope

Wire format of accepted rows; the session layer; a release or tag.

## Flagged concerns

None.
