# Per-round aligned values in TypeScript, C# and Python rounds

**Task**: AZ-2134_aligned_round_values
**Name**: Aligned round values
**Description**: Values under `flags` / `when` inside a `repeat` / `times` round keep one list entry per round in TypeScript, C# and Python, and C# stops dropping values under `flags` in a round.
**Complexity**: 5 points (split per package when refined)
**Dependencies**: AZ-2079, AZ-2080, AZ-2083
**Component**: typescript, csharp, python
**Tracker**: AZ-2134
**Epic**: AZ-2069

## Problem

Loop 12 feature assessment (`_docs/loops/loop12/assessment12.md` U2, G5), deferred from loop 12 by the owner.

- **U2**: Java, C++ and Rust `repeat` keep one entry per round (null for a skipped round). TypeScript, C# and Python append only set rounds, so `on: [true, false, true]` unpacks as `[true, true]`; the TS repack of that row is `01030103020203` instead of `01030102020303` (a `true` moves to another round). The same holds for any optional value under `flags` or `when` in a round.
- **G5**: C# drops values under `flags` in a round on pack: `Repeat(0, Flags(0, Bool On, U8 N))`, On=[T,F,T], N=[1,2,3] → `01` (TS/Java `01030102020303`); `Times(1, 0, Flags(1, Bool On, U8 N))`, A=3 → `0103000000`; `Repeat(0, U8 X, Flags(1, U8 N))`, X=[1,2], N=[5,null] → `0101000200` (N=5 lost). `RepeatCount` / `SliceValues` read direct-child names only.

## Owner decision (2026-10-05)

U2: A — aligned everywhere: one list entry per round (`null` / `None` / `undefined` for a skipped round); pack reads by round index. Reverses AZ-2100's "absent items are not appended, same as TS".

## Acceptance Criteria

**AC-1**: `repeat(flags(bool on, u8 n))` with on=[T,F,T], n=[1,2,3] packs `01030102020303` in TS, C#, Python and unpacks `on: [true, null, true]`, `n: [1, 2, 3]` (each package's null), and repacks to the same bytes.
**AC-2**: the same body in `times` with count 3 packs `0103030102020303` in all three.
**AC-3**: C# `Repeat(0, U8 X, Flags(1, U8 N))` with X=[1,2], N=[5,null] packs `010101050200`.
**AC-4**: golden and route fixtures unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Unpacked row shape changes in three packages (README upgrade note); split into one task per package when the loop takes it | coordinator | open | Medium |
