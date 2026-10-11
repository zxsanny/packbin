---
loop: 20
branch: dev
---

# `pack` has one output budget, `maxBytes` (default 16 MiB), and charges `maxSlots` per round as unpack does

**Task**: AZ-2354_pack_output_budget
**Name**: Pack output budget
**Description**: Every `pack` call refuses, naming the member, before the append that would make the packet longer than the scheme's `maxBytes` (default 16 MiB, raisable), and refuses a round whose slots would pass `maxSlots`, as unpack does.
**Complexity**: 5 points
**Dependencies**: AZ-2329 (done)
**Component**: typescript (reference, first), python, java, csharp, rust. C++ is not affected (caller buffer, fixed arrays).
**Tracker**: AZ-2354
**Epic**: AZ-2069

## Problem

Owner decision 1 of loop 20 (security F28, option A, accepted as recommended 2026-10-11). The loop 19 round cap bounds one `times` count, not the output: a lone `utf8` of 65 535 bytes under one `times` of 65 535 packs 4.29 GB from a 64 KB request (Python 4.2 s and 7.3 GB, Rust 1.9 s and 7.5 GB, Java no result in 100 s); a list element holding a `times` repeats the cap per element; a `times` inside a `repeat` round the same. `Scheme.maxSlots` is read by unpack only, so pack also writes packets its own unpack refuses (F31, review A5).

## Outcome

- One budget per `pack` call. The output never grows past `maxBytes`; a call that would is refused with the same typed error as the count cap (TypeScript `RangeError`, Python `ValueError`, Java `IllegalArgumentException`, C# `ArgumentException`, Rust `PackError`), naming the member being written, and returns no bytes.
- Pack charges `maxSlots` per round started, with the same width unpack charges, so a packet pack writes is a packet the same scheme unpacks.
- Rows at or under both limits pack to the same bytes as today.

## Scope

### Included
- `maxBytes` scheme limit, default 16 777 216, validated like the other limits (a positive integer), carried by `withLimits` in each package (problem D3: TypeScript `withLimits({ maxBytes })`, Python `with_limits(max_bytes=...)`, C# optional `maxBytes`, Rust `with_max_bytes`, Java `withMaxBytes`; Rust `MapScheme` and the C# dictionary/typed schemes too).
- The check where bytes are written: TypeScript `out` in `BinaryPacker.pack` (`PackState`), the Python `bytearray`, Java `ByteSink`, C# `List<byte>` through the walker scope, Rust `out`. Refuse before the append that would pass the budget (problem D2: the type byte counts).
- Slot charge on pack per round (`repeat` and `times`, at the top level, in `flags`, groups, `when`, split bits, list and dict elements, nested rounds), the same width as each package's unpack.
- **TypeScript first**: it writes `_docs/03_implementation/reference_loop20_budget.md` (scheme, row, outcome, exact error text, hex for accepted rows, byte length at the boundary). The other four align against it in wave 1b.

### Excluded
- Unpack (its input length is the caller's); the session layer; C++; changing `maxRounds` or `maxSlots` defaults.

## Acceptance Criteria

**AC-1: lone string under a capped `times` is refused**
Given `u32 n; times(n) { utf8 s }` and `{n: 65535, s: "a" × 65535}`
When packed in each of the five packages at default limits
Then an error naming `s` is raised in under 1 s, with peak resident memory under 256 MB, and no bytes are returned

**AC-2: an element that holds a `times` is refused at the default and packs with a raised budget**
Given `list(group(u32 n, times(n) { u64 k }))` with 40 items `{n: 65535, k: 5}` (about 21 MB of output, 2 621 400 slots: under `maxSlots`, so the byte budget is what refuses)
When packed at default limits, then with `maxBytes` raised to 33 554 432
Then the first is refused naming `k`; the second packs and unpacks to the same row

**AC-3: the boundary is exact**
Given a scheme and a row whose packet is exactly `maxBytes` bytes (a small `maxBytes` such as 64 is fine)
When packed, and when the row grows by one byte
Then the first packs; the second is refused and returns no bytes

**AC-4: slots are charged on pack**
Given a `times` round of 65 named `u8` members and a count of 65 535 (4 259 775 slots, above the default 4 194 304)
When packed
Then refused naming the member; with `maxSlots` raised to 4 259 775 it packs and unpacks

**AC-5: limits API**
Given the limits call without `maxBytes`
When the scheme is built
Then `maxBytes` is 16 777 216; a `maxBytes` below 1 or not an integer is refused like the other limits; existing calls compile unchanged

**AC-6: accepted rows keep their bytes**
Given the golden, route and ring fixtures
When run
Then every accepted row packs to the same hex as before

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | lone utf8 under times | error naming `s`, < 1 s, < 256 MB |
| AC-2 | element with a times, 40 items of u64 | refused; packs at 32 MiB |
| AC-3 | packet of `maxBytes` and `maxBytes + 1` | packs / refused |
| AC-4 | 65-name round × 65 535 | refused; packs with raised `maxSlots` |
| AC-5 | default, invalid, compat | 16 MiB, refused, compiles |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2, AC-4 | hostile `pack` stage | `pack_lone_utf8_under_times_over_budget`, `pack_element_times_over_budget`, `pack_slots_over_limit` (AZ-2367) | error, no bytes | — |
| AC-6 | golden/route/ring | full suite | unchanged | — |

## Constraints

- **Reference (wave 1a, parent-checked 2026-10-11):** `_docs/03_implementation/reference_loop20_budget.md` is the contract for wave 1b: same outcome, same member named, same numbers in the message, per package error type. Rows 1 to 28 cover AC-1 to AC-6; the order of checks (rounds, then per round slots before bytes) and the width a round charges are in its "rules" section. Parent decisions on the worker's open choices: a combined `flags` byte that would pass the budget is named by the first name its members declare, depth-first (confirmed); a refused `repeat` names the first member whose list passes the limit (confirmed).
- Each wave 1b worker measures AC-1 peak memory with `/usr/bin/time -l` (or the language's equivalent): a growable list of boxed values can miss the 256 MB bound (TypeScript `number[]` measured 554 MB for 16.7 M bytes), so use a primitive byte buffer that never grows past `maxBytes`.
- ADR-001: each package implements it itself; no shared walker.
- The reference table is written before the other four packages start; every AC above is checked against its rows by the parent first (retro lesson, loop 19).
- Hot path: one integer comparison per append; no per-byte allocation.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A row above 16 MiB that packs today is refused after the upgrade | README upgrade note; raisable | accepted-risk | Medium |
