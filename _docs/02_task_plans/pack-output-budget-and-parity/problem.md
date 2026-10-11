---
loop: 20
branch: dev
---

# Loop 20 — pack output budget and the loop 19 parity follow-ups

Loop 20 (on `dev`; no worktree). Intake: `_docs/loops/loop20/handoff20.md`. Owner decisions taken 2026-10-11 ("accept all recommended": decisions 1 to 9, all option A; the F28 wave comes before the Go package).

## Change location

A library with no running app. The change sits in the pack walkers and scheme limits of the five growable packages (`typescript/`, `python/`, `java/`, `csharp/`, `rust/`), two C++ split-bit fixes in `cpp/src/core` (pack side), the hostile fixture set `fixtures/hostile/` (new `pack` cases) and the README limits section (verbal, from the handoff: "decide the table above; wave 1 F28 budget in the five packages with a Rust or TypeScript reference first, then G1 to G5 and F29/F30").

## What

1. Give every `pack` call one output budget, `maxBytes` (default 16 MiB, raised through the scheme limits), and charge `maxSlots` per round on pack as unpack does, so the round cap of loop 19 bounds the packet and not just one count (security F28), and pack never writes a packet its own unpack refuses (F31: also `repeat` above `maxRounds`).
2. Close the parity rows the owner decided: count 0 after the byte with a list (U2), C++ count behind a clear `when` (U4), whole-number floats in C# (U5), enums pinned and documented (U6), combined `flags` skipped count with values (B6). U3 (keep) and U7 (leave C++ `eq(u8, true)`) change no code: upgrade-note text in step 13.
3. Close the clear gaps: Java G1/F29/F30, Python G2, TypeScript G3, C++ G4, file splits G5, C# F17/F27 (typed error, checks inside rounds).

## Who

Callers of the library who pack rows built from requests they do not trust (the budget), callers who pack with one package and unpack with another (parity), and the package owner (single publisher).

## Decisions made while grasping (the owner can change any)

- **D1** TypeScript is the reference package for AZ-2354 and AZ-2355: it implements first and writes a hex-pinned reference table (scheme, row, outcome, error text) in `_docs/03_implementation/reference_loop20_budget.md`; the parent checks every AC of AZ-2354/AZ-2355 against it before wave 1b starts (retro lesson, loop 19).
- **D2** `maxBytes` counts the whole packet, type byte included; it is a pack limit only (unpack already holds its input). Pack refuses before the append that would pass it, so the output never grows past the budget.
- **D3** Existing limit call forms keep compiling: TypeScript `withLimits({ maxBytes })`, Python `with_limits(max_bytes=...)`, C# an optional `maxBytes` parameter; Rust and Java, whose `with_limits(maxRounds, maxSlots)` is positional, add a separate method (`with_max_bytes` / `withMaxBytes`) instead of a third argument.
- **D4** C++ is out of AZ-2354 and AZ-2355: it packs into a caller buffer with a fixed capacity and fixed arrays.
- **D5** F17 is fixed by returning a typed error from the C# `Dispatch`; binding typed rounds to a collection of rows (the loop 13 direction) stays out of scope.
- **D6** Out of scope: Go (AZ-2222, next), Swift (AZ-2223), AZ-2068 (C++ AVR stretch), any tag, the traceability catch-up of loops 11 to 18 beyond what step 12 does cheaply.

## Out of scope

Wire format changes for accepted rows; the session layer (it wraps a packed packet, the budget applies to `pack` only); Go and Swift packages; a release or tag.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A row that packs today above 16 MiB (or above `maxSlots`, or a `repeat` above `maxRounds`) is refused after the upgrade | upgrade notes in step 13; the limit is raisable | accepted-risk | Medium |
| Cortex-M4F flash margin is 128 B and AZ-2357 costs about 56 B; AZ-2364 adds more | C++ worker measures both; stop if the margin goes below 32 B | open | Medium |
| Stack margin 56 B on Cortex-M4F; any `cpp/src/core` edit runs the arm stage | coordinator | open | Medium |
