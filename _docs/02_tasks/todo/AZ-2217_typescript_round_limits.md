# TypeScript unpack refuses rounds above the scheme's limits

**Task**: AZ-2217_typescript_round_limits
**Name**: TypeScript round and slot limits on unpack
**Description**: A TypeScript `Scheme` carries `maxRounds` and `maxSlots` (defaults 65,535 and 4,194,304); an unpack that would create more rounds or slots is refused with the interim bad-value error when the round that crosses a limit would start, and a caller can raise or lower the limits per scheme with `withLimits`.
**Complexity**: 3 points
**Dependencies**: None (the shared hostile case and the README are AZ-2220, which lands after this task)
**Component**: typescript
**Tracker**: AZ-2217
**Epic**: AZ-2069

## Problem

Loop 15, finding F10 (`_docs/05_security/security_report.md`), owner option A, decisions D1 to D7 in `_docs/02_task_plans/unpack-limits-and-ci-hardening/problem.md`.

Unpack of a `repeat` or `times` round has no budget. Facts on the current code (`b45335d`):

- The `repeat` case of `unpackFields` (`walker.ts:118-132`) loops `while (cur.offset < cur.buf.length)`; the `times` case (`walker.ts:175-190`) loops a `number` count. Both feed a `RoundLists` (`rounds.ts:107-142`), which pads every name the round can hold (`roundNames`, `rounds.ts:43-47`) to one entry per round. A round must read at least one byte, so rounds are bounded only by the bytes left.
- Cost: a 1 MiB packet of one-byte rounds with a 36-name `when` body is about 401 MB peak (audit; the README says "about 400 MB").
- The only defence today is the README sentence "cap the packet length where you read it" (`README.md:1081`).
- The unpack entry points cannot take an extra argument: `BinaryPacker.unpack(bytes, first, ...rest)` (`index.ts:96-102`) and `PackSession.unpack` (`index.ts:178`, calls it); both go through `unpackDispatch` (`index.ts:109-128`), which calls `unpackBody(match.scheme.fields, buf, 1)` (`index.ts:124`). So the limits live on the scheme (D1).
- `Scheme<T>` (`index.ts:59-82`) has readonly `typeNumber` and `fields`; its constructor is `(typeNumber, fields)` and runs every check. `scheme(typeNumber, ...fields)` (`index.ts:84-86`) takes a rest parameter, so it cannot take a trailing option.
- `ViewCursor` (`kinds.ts:298`, `{ buf, view, offset }`) is created once per call in `unpackBody` (`walker.ts:259-275`) and passed to every nested `unpackFields`, list and dict elements included; it is the per-call carrier.
- Error mechanism: `{ ok: false, field, needed, left }`. A bad value uses `needed` 0: `unreadable(field, cur)` (`walker.ts:28-30`), which the zero-width `times` round and an unreadable count already call with `firstName(f.fields)` (`walker.ts:177`, `:185`). C15 (a real error kind and label) is the owner's open decision, so the refusal uses this error.
- The largest existing use is `tests/round-roundtrip.test.ts:158-180`: 50,000 rounds x 37 names = 1,850,000 slots, under both defaults.

## Outcome

- A scheme has `maxRounds` (default 65,535) and `maxSlots` (default 4,194,304). `withLimits(...)` returns a scheme with other values; the receiver is unchanged.
- An unpack that would start more than `maxRounds` rounds of one `repeat` or `times` field, or whose rounds together would hold more than `maxSlots` slots, returns `{ ok: false, field, needed: 0, left }`, the handler is not called, no row is visible.
- A refused 1 MiB packet does work bounded by the limits, not by the packet length.
- A packet at or below the limits unpacks exactly as before. Pack, wire bytes and result shapes do not change.

## Public surface (the names the implementer must use)

- `Scheme.DefaultMaxRounds` (65535) and `Scheme.DefaultMaxSlots` (4194304): static readonly, as `PackSession.SeedSize` (`index.ts:136`).
- `scheme.maxRounds` and `scheme.maxSlots`: readonly numbers.
- `scheme.withLimits(limits: { maxRounds?: number; maxSlots?: number }): Scheme<T>` returns a new `Scheme` with the same `typeNumber` and the same fields. An omitted member takes the default, not the receiver's current value; `withLimits()` gives the defaults. `new Scheme(typeNumber, fields)` and `scheme(...)` keep their signatures. (Rebuilding from `this.fields`, which is the flattened bound list, was checked in a scratch run to construct without error.)
- Construction error (D6): a limit that is not a positive safe integer (0, negative, fractional, `NaN`, `Infinity`, above `Number.MAX_SAFE_INTEGER`) throws `RangeError` whose message names `maxRounds` or `maxSlots`, the same type the type-number check uses (`index.ts:67`). No "unlimited" value: `Number.MAX_SAFE_INTEGER` is valid.

## What is counted and when it is checked (D2, D5)

- Rounds: the rounds one `repeat` or `times` field starts in one walk of that field.
- Slots: for each round started, the size of `roundNames(f.fields, false)` (the entries `RoundLists` pads per round), added to one total kept on the `ViewCursor` and shared by every field of the unpack call.
- `repeat`: at the start of a round (only when bytes are left), refuse if the field has already started `maxRounds` rounds or if total slots + this round's names > `maxSlots`.
- `times`: the same check at the start of each round: refuse the (`maxRounds` + 1)th round, or a round that would take total slots above `maxSlots`. The count field is not refused up front (D5, lazy, 2026-10-06): a huge count whose packet ends early gives today's short read.
- `left` in the error is `cur.buf.length - cur.offset` at the refusal; the buffer includes the type byte.
- Label (D4): `firstName(f.fields)`, as the zero-width `times` round at `walker.ts:185`, for both `repeat` and `times`.

## Scope

### Included
- `Scheme`: the two limits, `withLimits`, the defaults, validation; passing the scheme's limits to `unpackBody`.
- The refusal in the `repeat` and `times` cases, the counter on `ViewCursor`.
- New tests (below).

### Excluded
- Pack, wire bytes, result shapes, session and dispatch behavior (D7); list and dict counts; `bits` and `packed`.
- A distinct error kind (C15), the README, the hostile case and the docs (AZ-2220).
- C++ and Python.

## Acceptance Criteria

**AC-1: Defaults and surface**
Given any scheme built as today, and `scheme.withLimits({ maxRounds: 10 })`
When `maxRounds`, `maxSlots`, `Scheme.DefaultMaxRounds` and `Scheme.DefaultMaxSlots` are read
Then the first has 65,535 and 4,194,304; the constants have those values; the second has `maxRounds` 10 and `maxSlots` 4,194,304.

**AC-2: `repeat` at the default limit**
Given `scheme<Row>(1, repeat(0, [u8(0, (x) => x.k)]))`
When a packet of type `01` followed by 65,535 one-byte rounds, and one followed by 65,536 rounds, are unpacked with a handler
Then the first returns `{ ok: true }` and `k` has 65,535 entries; the second returns `{ ok: false, field: "k", needed: 0, left: 1 }` and the handler is not called.

**AC-3: `repeat` refused at the (maxRounds + 1)th round**
Given the scheme of AC-2 with `withLimits({ maxRounds: 3 })`
When `01aabbcc` and `01aabbccdd` are unpacked
Then the first returns `{ ok: true }` with row `{ k: [170, 187, 204] }`; the second returns `{ ok: false, field: "k", needed: 0, left: 1 }` (refused when round 4 would start, `dd` unread) and the handler is not called.

**AC-4: `times` refused at the (maxRounds + 1)th round**
Given `scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.k)]))` with `withLimits({ maxRounds: 3 })`
When `0103090909`, `010409090909`, `0104090909`, `01ff09` and `01030909` are unpacked
Then: ok with row `{ n: 3, k: [9, 9, 9] }`; `{ ok: false, field: "k", needed: 0, left: 1 }` (round 4 would start with one byte left); `{ ok: false, field: "k", needed: 0, left: 0 }` (count 4, three rounds present: refused when round 4 would start, before the short read of `k` the old code returns); `{ ok: false, field: "k", needed: 1, left: 0 }` (count 255, one round present: the limit is never reached, today's short read); and `{ ok: false, field: "k", needed: 1, left: 0 }` (count 3, two rounds present: unchanged).

**AC-5: `times` at the default limit**
Given `u32 n; times(1, 0, [u8 k])` and the default limits
When a packet with `n` = 65,535 followed by 65,535 bytes, one with `n` = 65,536 followed by 65,536 bytes, one with `n` = 4,294,967,295 followed by 65,536 bytes, one with `n` = 4,294,967,295 followed by 65,535 bytes, and `01ffffffff00` are unpacked
Then: ok with `k` of 65,535 entries; `{ ok: false, field: "k", needed: 0, left: 1 }`; `{ ok: false, field: "k", needed: 0, left: 1 }`; `{ ok: false, field: "k", needed: 0, left: 0 }`; and `{ ok: false, field: "k", needed: 1, left: 0 }` (count 4,294,967,295, one round present: today's short read, unchanged).

**AC-6: Slot limit**
Given `repeat(0, [u8(0, k), when(1, eq(0, 1), [u8(1, a), u8(2, b)])])` (three names: k, a, b) with `withLimits({ maxSlots: 6 })`
When `010000`, `01000000` and `0100000000` are unpacked
Then the first returns ok with `k` `[0, 0]` and `a`, `b` `[undefined, undefined]` (2 rounds x 3 = 6, exactly the limit); the second returns `{ ok: false, field: "k", needed: 0, left: 1 }`; the third `{ ok: false, field: "k", needed: 0, left: 2 }` (both refused when round 3 would start).

**AC-7: The slot total is per unpack call, across fields**
Given `u8 n; times(1, 0, [u8 k]); times(2, 0, [u8 v])` and the packet `0102aabbccdd`
When unpacked with `withLimits({ maxRounds: 3, maxSlots: 4 })` and with `withLimits({ maxRounds: 3, maxSlots: 3 })`
Then the first returns ok with `{ n: 2, k: [170, 187], v: [204, 221] }` (2 + 2 slots); the second returns `{ ok: false, field: "v", needed: 0, left: 1 }` (refused when round 2 of the second `times` would start).

**AC-8: A refused 1 MiB packet is bounded by the limits**
Given the scheme of `round-roundtrip.test.ts:158-180` (a `repeat` of `u8 k` and a `when` with 36 more names) and the default limits
When a packet of type `01` followed by 1,048,576 zero bytes is unpacked
Then it returns `{ ok: false, field: "k", needed: 0, left: 983041 }` (refused at round 65,536: the rest of the packet was not walked) and the handler is not called. A scratch run of this design measured 115 MiB resident for this call, against about 401 MB documented before; the old code returns `{ ok: true }` here, so the test fails on the unfixed tree.

**AC-9: Limits belong to the scheme**
Given `base` (default limits), `strict = base.withLimits({ maxRounds: 3 })`, and a second scheme `other` of type 2 with `withLimits({ maxRounds: 2 })`
When `01aabbccdd` is unpacked with `base.on(...)`, then with `strict.on(...)`, and `02aabbcc` is unpacked with `base.on(...)` and `other.on(...)` in one call
Then the first returns ok with four entries in `k` (the receiver kept its limits); the second returns `{ ok: false, field: "k", needed: 0, left: 1 }`; the third returns `{ ok: false, field: "k", needed: 0, left: 1 }` from `other`'s limit.

**AC-10: Invalid limits are refused at construction**
Given any scheme
When `withLimits` gets `{ maxRounds: 0 }`, `{ maxRounds: -1 }`, `{ maxRounds: 1.5 }`, `{ maxRounds: NaN }`, `{ maxRounds: Infinity }`, `{ maxSlots: 0 }`, `{ maxSlots: 2 ** 53 }`, and `{ maxRounds: Number.MAX_SAFE_INTEGER, maxSlots: Number.MAX_SAFE_INTEGER }`
Then the first seven throw `RangeError` naming `maxRounds` or `maxSlots`, and the last returns a scheme that unpacks the 65,536-round packet of AC-2.

**AC-11: Nothing else changes**
Given the existing TypeScript tests
When `node --test tests/*.ts` and `tsc --noEmit --strict` run
Then every test passes without an edit, including the 50,000 x 37 test and the shared vector `oversize_count_times` (`01ffffffff00` still gives a short read of `k` with `needed` 1, classified `short_packet`, because round 1 starts and round 2 never does). No hostile vector and no test assertion changes. A scratch prototype of this (lazy) design: 241 of 241 tests pass.

## Non-Functional Requirements

**Performance**
- One comparison per round start and per `times` count; the existing suite time does not grow. A refused call returns in well under 1 s (17 ms measured for the 1 MiB packet of AC-8).

**Compatibility**
- A packet with more than 65,535 rounds, or more than 4,194,304 slots, that unpacked before is refused until the scheme raises the limit (upgrade note in AZ-2220). No existing test or README example reaches either default (the 241 existing tests pass against the lazy prototype).

**Reliability**
- A refusal returns an error value; no exception, no partial row, no handler call.

## Unit Tests

New file `typescript/tests/round-limits.test.ts` (`node:test`, AAA as `round-roundtrip.test.ts`).

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | defaults, constants, `withLimits({ maxRounds: 10 })` | 65,535 / 4,194,304; omitted member is the default |
| AC-2 | 65,535 and 65,536 one-byte `repeat` rounds, defaults | ok, 65,535 entries; `{ field: "k", needed: 0, left: 1 }`, handler not called |
| AC-3 | `01aabbcc`, `01aabbccdd` with `maxRounds` 3 | row `{ k: [170, 187, 204] }`; `left: 1` |
| AC-4 | five `times` packets, `maxRounds` 3 | exact shapes in AC-4 |
| AC-5 | u32-count `times`: 65,535; 65,536; max count + 65,536 bytes; max count + 65,535 bytes; `01ffffffff00` | ok; `left: 1`; `left: 1`; `left: 0`; `{ needed: 1, left: 0 }` |
| AC-6 | three-name `repeat`, `maxSlots` 6, three packets | ok; `left: 1`; `left: 2` |
| AC-7 | two `times` fields, `maxSlots` 4 and 3 | ok row; `{ field: "v", needed: 0, left: 1 }` |
| AC-8 | 1 MiB, 36-name body, defaults | `{ field: "k", needed: 0, left: 983041 }` |
| AC-9 | receiver unchanged; `strict`; dispatch with two schemes | as listed |
| AC-10 | eight `withLimits` calls | seven `RangeError` naming the member; one scheme accepting 65,536 rounds |
| AC-11 | existing suite (no edit), strict typecheck | green |

Run each new test against the unfixed tree first and require it to fail (AC-2 to AC-8 do).

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | default scheme, 65,536 one-byte rounds | `BinaryPacker.unpack(bytes, scheme.on(h))` | `{ ok: false, field: "k", needed: 0, left: 1 }`, `h` not called | Reliability |
| AC-4 | `times` scheme, `maxRounds` 3, `010409090909` | public `unpack` | `left: 1`, no row | Reliability |
| AC-8 | 36-name scheme, 1 MiB | public `unpack`, elapsed time | `left: 983041`, returns in under 1 s | Performance |
| AC-9 | two handlers of types 1 and 2 | public `unpack` of a type 2 packet with 3 rounds | `left: 1` from the type 2 scheme's limit | Reliability |
| AC-11 | existing `hostile.test.ts` vector replay | `oversize_count_times` | unchanged: `short_packet`, accepted by the line as written | Compatibility |

## Constraints

- **Owns**: `typescript/**` only (`src/index.ts`, `src/walker.ts`, `src/kinds.ts` and the new `typescript/tests/round-limits.test.ts`). **Forbidden**: `fixtures/**`, `README.md`, `_docs/**`, the other packages, the workflows. The hostile `limit` replay is AZ-2220, which lands after this task.
- Simplicity (coderule.md): two numbers on the scheme, one counter on the existing `ViewCursor`; no new class. No module-level mutable state.
- Per `_docs/LESSONS.md` (loop 11) CI has no typecheck job: run `typescript/node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions typescript/src/index.ts` before the commit (`_docs/AGENT_GOTCHAS.md`), and the project's formatter and CI-parity jobs.
- Test command: `node --test tests/*.ts` in `typescript/`.
- Files stay under 500 lines (`walker.ts` is 275, `rounds.ts` 150, `index.ts` 209).

## Risks & Mitigation

**Risk 1: Label of a refused `repeat`**
- *Risk*: the label is the first member name (`k`), so only `needed` 0 tells a refusal from a normal short read of `k`.
- *Mitigation*: same convention as the zero-width `times` error; the label is part of the C15 decision.

**Risk 2: `withLimits` rebuilding the scheme**
- *Risk*: re-running the constructor on `this.fields` could change fields (flatten, bind).
- *Mitigation*: AC-9 and the existing scheme tests; a scratch run showed the rebuild is idempotent, but share the receiver's fields if a check differs.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| D5 (lazy, owner decision 2026-10-06): a `times` count above `maxRounds` is not refused up front; the (maxRounds + 1)th round start is. The first draft (eager) turned `01ffffffff00` into a `bad_value`-kind answer that failed the shared vector replay; lazy leaves the vector and the line untouched, and bounds memory equally | owner (D5) | resolved | Low |
| Label of the refusal (the first member name) and the error kind are interim until C15 | owner (C15) | accepted-risk | Low |
| Public surface grows by one method, two readonly properties, two statics (D1, shape recorded as a default) | owner | accepted-risk | Low |
| Round-holding list or dict elements are not supported in TypeScript today (AZ-2102), so no test shows the counter shared with an element; the counter lives on the `ViewCursor`, which elements already share | AZ-2102 owner | accepted-risk | Low |
