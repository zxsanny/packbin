---
loop: 19
branch: dev
---

# Loop 19 — round, flag and construction parity across the six packages

Loop 19 (on `dev`; no worktree). Intake: `_docs/loops/loop19/handoff19.md`. Owner decisions taken 2026-10-11 ("accept all recommended": decisions 1 to 3, then 4 to 13) and scope "hopper + clear gaps, Go next loop".

## Change location

A library with no running app. The change sits in the six packages' pack/unpack walkers and scheme builders (`typescript/`, `python/`, `java/`, `csharp/`, `rust/`, `cpp/`), the hostile fixture set `fixtures/hostile/` (new `pack` cases) and `run-suite.sh` (verbal, from the handoff: "owner decisions 1 to 11 as specs, plus the clear gaps").

## What

Make the six packages give the same bytes or the same refusal for the same scheme and row, on the shapes the loop 18 review and assessment found different (decisions 1 to 9, 11, 13) and close the clear gaps (C++ `present()` pin, Python venv check, near-cap file splits). Decisions 10 and 12 change no code (kept refusal of the broader C# member-type set; C# stays in the rings as a chain): they become upgrade-note text in step 13.

## Who

Callers of the library who pack with one package and unpack with another, and the package owner (single publisher).

## Decisions made while grasping (the owner can change any)

- **D1** The pack cap reuses the scheme's `maxRounds` (default 65 535) instead of a new property; a scheme that raised the unpack limit packs that many rounds.
- **D2** Decision 13 is a probe only (AZ-2339): follow-up specs go to the loop 20 handoff.
- **D3** Per-package order in each worker: file split first (AZ-2342), then the behavior specs; the shared fixture work (hostile `pack`/`construct` cases) is a second wave, after every package refuses.
- **D4** Out of scope: Go (AZ-2222, loop 20), Swift, F17/F27 (the typed unpack of a set round), AZ-2068, any tag.

## Out of scope

Wire format changes other than Python's round scope (decision 2); Go and Swift packages; a release or tag.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Python bytes change for one shape (decision 2); Rust bytes change for sibling flags (decision 5); callers relying on broadcast of a lone byte buffer break (decision 4) | upgrade notes in step 13 | accepted-risk | Medium |
| Embedded Cortex-M4F stack margin is 56 B; C++ changes must be measured | coordinator | open | Medium |
