# C# unpack refuses rounds above the scheme's limits

**Task**: AZ-2216_csharp_round_limits
**Name**: C# round and slot limits on unpack
**Description**: A C# scheme carries `maxRounds` and `maxSlots` (defaults 65,535 and 4,194,304); an unpack that would create more rounds or slots is refused with the interim bad-value error when the round that crosses a limit would start, and a caller can raise or lower the limits per scheme.
**Complexity**: 3 points
**Dependencies**: None (the shared hostile case and the README are AZ-2220, which lands after this task; AZ-2119 touches the same list element unpack path, see Flagged concerns)
**Component**: csharp
**Tracker**: AZ-2216
**Epic**: AZ-2069

## Problem

Loop 15, finding F10 (`_docs/05_security/security_report.md`), owner option A (a limit on unpack), decisions D1 to D7 in `_docs/02_task_plans/unpack-limits-and-ci-hardening/problem.md`.

Unpack of a `repeat` or `times` round has no budget. Facts on the current code (`b45335d`):

- `UnpackRepeat` (`Walker.cs:281-304`) loops `while (offset < bytes.Length)`; `UnpackTimes` (`Walker.Counted.cs:260-288`) loops a `long` count. Every round gets a new `Scope` and, through `AppendRound` (`Walker.Rounds.cs:132-138`), one list entry for every name the round can hold (`RoundNames`, `Walker.Rounds.cs:59-94`), `null` where the round skipped it. A round must read at least one byte, so rounds are bounded only by the bytes left.
- A 1 MiB packet of one-byte rounds therefore costs memory proportional to rounds x names. Measured on the current code in a scratch copy (limits disabled), `Scheme` with a `repeat` of one `u8` and a `when` holding 36 more names: 2,752 MiB allocated in total; with 4 names: 608 MiB. The audit measured 525 MB peak for the 36-name body.
- The only defence today is the README sentence "cap the packet length where you read it from the network" (`README.md:1081`).
- The unpack entry points cannot take an extra argument without a breaking overload: `BinaryPacker.Unpack(ReadOnlySpan<byte>, params SchemeHandler[])` (`Packbin.cs:136`), `PackSession.Unpack` (`PackSession.cs`, calls the same), the internal `BinaryPacker.Read<T>(Scheme<T>, bytes)` (`Packbin.cs:159`, used by the tests). All three reach `ReadFields(scheme.Fields, bytes)` (`Packbin.cs:45`, `:166`, `:169`). So the limits live on the scheme (D1).
- `Scheme<T>` is sealed and immutable (`Packbin.cs:3-22`: get-only `TypeNumber` and `Fields`, set in the constructor, which takes `params Field[]` and so cannot take a trailing option).
- `Scope` (`Scope.cs`) is documented as "state owned by one call"; `ReadFields` creates the top one (`Packbin.cs:171`) and every round, list element and dictionary value gets a new one (`Walker.cs:291`, `Walker.Counted.cs:273`, `:362`, `:433`).
- Error mechanism: `object?` result; a bad value is `ShortPacket(field, 0, left)` through the one method `InterimBadValue` (`Walker.Counted.cs:80-82`); the zero-width `times` round already uses it with the label `times` (`Walker.Counted.cs:282`). C15 (a real error kind and label) is the owner's open decision, so the refusal uses this error.

## Outcome

- A scheme has `MaxRounds` (default 65,535) and `MaxSlots` (default 4,194,304). `WithLimits(...)` returns a scheme with other values; the receiver is unchanged.
- An unpack that would start more than `MaxRounds` rounds of one `repeat` or `times` field, or whose rounds together would hold more than `MaxSlots` slots, returns `ShortPacket(label, 0, left)`, the handler is not called, no row is visible.
- Memory for a refused 1 MiB packet is bounded by the limits, not by the packet length.
- A packet at or below the limits unpacks exactly as before. Pack, wire bytes and result shapes do not change.

## Public surface (the names the implementer must use)

- `BinaryPacker.DefaultMaxRounds` (`const int` 65,535) and `BinaryPacker.DefaultMaxSlots` (`const long` 4,194,304). `BinaryPacker` is the existing public non-generic static class; `Scheme<T>` is generic, so the constants do not live there.
- `Scheme<T>.MaxRounds` (`int`) and `Scheme<T>.MaxSlots` (`long`), get-only.
- `Scheme<T>.WithLimits(int maxRounds = BinaryPacker.DefaultMaxRounds, long maxSlots = BinaryPacker.DefaultMaxSlots)` returns a new `Scheme<T>` with the same type number and the same resolved fields (it does not resolve the fields again). An omitted argument takes the default, not the receiver's current value.
- Construction error (D6): `maxRounds < 1` or `maxSlots < 1` throws `ArgumentOutOfRangeException` with `ParamName` `maxRounds` or `maxSlots`, the same type the `typeNumber` check uses (`Packbin.cs:11`). No "unlimited" value: `int.MaxValue` and `long.MaxValue` are valid.

## What is counted and when it is checked (D2, D5)

- Rounds: the rounds one `repeat` or `times` field starts in one walk of that field. A field walked again (inside a list element) counts afresh.
- Slots: for each round started, the number of distinct names `RoundNames(field, packing: false)` returns (the entries `AppendRound` adds per round); added to one total shared by every field of the unpack call, including fields in list and dictionary elements and nested rows.
- `repeat`: at the start of a round (only when bytes are left), refuse if the field has already started `MaxRounds` rounds or if total slots + this round's names > `MaxSlots`.
- `times`: the same check at the start of each round: refuse the (`MaxRounds` + 1)th round, or a round that would take total slots above `MaxSlots`. The count field is not refused up front (D5, lazy, 2026-10-06): a count above `MaxRounds` is refused only if the packet really holds that many rounds, so what happens to a packet whose count is huge and whose bytes end early is today's short read.
- A round is checked before its bytes are read, so `left` in the error is the bytes left at that point (`bytes.Length - offset`; the type byte is not part of `bytes`).
- Label (D4): the round field's own name, as `InterimBadValue(field.Name, left)`: `""` for `repeat` (`Field.Repeat` has the name `""`), `times` for `times`.

## Scope

### Included
- The two limits on `Scheme<T>`, `WithLimits`, the defaults, the validation.
- The refusal in `UnpackRepeat` and `UnpackTimes`, with the per-call slot total carried to every scope of the call (the `Scope` is the existing per-call carrier; list and dictionary element scopes must share it).
- `BinaryPacker.Unpack` / `SchemeHandler.Dispatch` and `BinaryPacker.Read` pass the scheme's limits to `ReadFields`.
- New tests (below). No existing test changes (AC-11).

### Excluded
- Pack, wire bytes, result shapes, session and dispatch behavior (D7); list and dictionary counts (u16); `bits` and `packed`.
- A distinct error kind (C15), the README, the hostile case and the docs (AZ-2220).
- C++ and Python (no change, AZ-2220 records why).

## Acceptance Criteria

**AC-1: Defaults and surface**
Given any scheme built as today, and one built with `WithLimits()`
When `MaxRounds`, `MaxSlots`, `BinaryPacker.DefaultMaxRounds` and `BinaryPacker.DefaultMaxSlots` are read
Then they are 65,535 and 4,194,304, and `WithLimits(maxRounds: 10)` has `MaxSlots` 4,194,304 (the default, not inherited).

**AC-2: `repeat` at the default limit**
Given `new Scheme<R>(1, Field.Repeat(0, Field.U8<R>(0, x => x.K)))` (`K` a `byte?`)
When a packet of type `01` followed by 65,535 one-byte rounds is read with `BinaryPacker.Read`, and one followed by 65,536 rounds with `BinaryPacker.Unpack(bytes, scheme.On(...))`
Then the first has no error and `K` holds 65,535 entries; the second returns `ShortPacket("", 0, 1)` and the handler is not called.

**AC-3: `repeat` refused at the (maxRounds + 1)th round**
Given the scheme of AC-2 with `WithLimits(maxRounds: 3)`
When `01aabbcc` and `01aabbccdd` are read
Then the first has no error and `K` is `[0xaa, 0xbb, 0xcc]`; the second returns `ShortPacket("", 0, 1)` (refused when round 4 would start, `dd` unread) and the row has no `K`.

**AC-4: `times` refused at the (maxRounds + 1)th round**
Given `new Scheme<R>(1, Field.U8<R>(0, x => x.N), Field.Times(1, 0, Field.U8<R>(1, x => x.K)))` with `WithLimits(maxRounds: 3)`
When `0103090909`, `010409090909`, `0104090909`, `01ff09` and `01030909` are read
Then: no error with `K` `[9, 9, 9]`; `ShortPacket("times", 0, 1)` (round 4 would start with one byte left); `ShortPacket("times", 0, 0)` (count 4, three rounds present: the refusal is made when round 4 would start, before the short read of `K` that the old code returns); `ShortPacket("K", 1, 0)` (count 255, one round present: the limit is never reached, today's short read); and `ShortPacket("K", 1, 0)` (count 3, two rounds present: unchanged).

**AC-5: `times` at the default limit**
Given `U32 N; Times(1, 0, U8 K)` and the default limits
When a packet with `N` = 65,535 followed by 65,535 bytes, one with `N` = 65,536 followed by 65,536 bytes, one with `N` = 4,294,967,295 followed by 65,536 bytes, one with `N` = 4,294,967,295 followed by 65,535 bytes, and `01ffffffff00` are read
Then: no error with `K` holding 65,535 entries; `ShortPacket("times", 0, 1)`; `ShortPacket("times", 0, 1)`; `ShortPacket("times", 0, 0)`; and `ShortPacket("K", 1, 0)` (count 4,294,967,295, one round present: today's short read, unchanged).

**AC-6: Slot limit**
Given `Field.Repeat(0, Field.U8<R>(0, x => x.K), Field.When(1, Condition.Eq(0, (byte)1), Field.U8<R>(1, x => x.A), Field.U8<R>(2, x => x.B)))` (three names: K, A, B) with `WithLimits(maxSlots: 6)`
When `010000`, `01000000` and `0100000000` are read
Then the first has no error (2 rounds x 3 = 6, exactly the limit); the second returns `ShortPacket("", 0, 1)` and the third `ShortPacket("", 0, 2)` (both refused when round 3 would start, with the rounds after it unread).

**AC-7: The slot total is per unpack call, across fields**
Given `U8 N; Times(1, 0, U8 K); Times(2, 0, U8 V)` and the packet `0102aabbccdd`
When read with `WithLimits(maxRounds: 3, maxSlots: 4)` and with `WithLimits(maxRounds: 3, maxSlots: 3)`
Then the first has no error (2 + 2 slots); the second returns `ShortPacket("times", 0, 1)` (refused when round 2 of the second `times` would start).

**AC-8: A refused 1 MiB packet is bounded by the limits**
Given `Repeat(0, U8 K, When(1, Eq(0, (byte)1), U8 A, U8 B, U8 C))` (four names) and the default limits
When a packet of type `01` followed by 1,048,576 zero bytes is read, measuring `GC.GetAllocatedBytesForCurrentThread()` before and after
Then it returns `ShortPacket("", 0, 983041)` and allocates less than 128 MiB (the prototype allocates 38.0 MiB; the same packet with the limits disabled allocates 608 MiB, so the test fails on the unfixed code).

**AC-9: Limits belong to the scheme**
Given `scheme` (default limits) and `strict = scheme.WithLimits(maxRounds: 3)`, and a second scheme `other` of type 2 built with `WithLimits(maxRounds: 2)`
When `BinaryPacker.Read(scheme, 01aabbccdd)` is read; `BinaryPacker.Unpack(01aabbccdd, strict.On(...))`; and `BinaryPacker.Unpack(02aabbcc, scheme.On(...), other.On(...))` is called
Then the first has no error and `K` has four entries (the receiver kept its limits); the second returns `ShortPacket("", 0, 1)`; the third returns `ShortPacket("", 0, 1)` from `other`'s limit while `scheme` is registered in the same call.

**AC-10: Invalid limits are refused at construction**
Given any scheme
When `WithLimits(maxRounds: 0)`, `WithLimits(maxRounds: -1)`, `WithLimits(maxSlots: 0)`, `WithLimits(maxSlots: -1)` are called, and `WithLimits(int.MaxValue, long.MaxValue)`
Then the first four throw `ArgumentOutOfRangeException` with `ParamName` `maxRounds` or `maxSlots`, and the last returns a scheme that unpacks the 65,536-round packet of AC-2.

**AC-11: Nothing else changes**
Given the existing C# tests
When the suite runs
Then every test passes without an edit, including `HostileUnpackTests.Ac3_U32TimesCountAboveInt32_ReturnsShortPacket` (`HostileUnpackTests.Counts.cs:136-148`, packet `01ffffffff00` still gives `ShortPacket("X", 1, 0)` because round 1 starts and round 2 never does), the 50,000-round tests, the zero-width tests (`Times_ZeroWidthBodyWith...`, label `times`) and the `oversize_count_times` vector. No hostile vector and no test assertion changes.

## Non-Functional Requirements

**Performance**
- The check is a comparison per round start and one per `times` count: no measurable cost on packets within the limits (the existing suite time does not grow).
- At the defaults the worst accepted case is 65,535 rounds; the measured allocation for 37 names x 65,535 rounds is 172 MiB in total (prototype), so the README memory figures change (AZ-2220).

**Compatibility**
- A packet with more than 65,535 rounds, or more than 4,194,304 slots, that unpacked before is refused until the scheme raises the limit (upgrade note in AZ-2220). No existing C# test and no README example reaches either default: in a scratch prototype of this (lazy) design the C# suite of 390 tests passes except `SchemeTests.CompileFailRequiresScheme`, which cannot find `csharp/tests/compile-fail` in the scratch layout (largest use in the repo: 50,000 rounds x 37 names in the TypeScript tests).

**Reliability**
- A refusal returns an error value; no exception, no partial row, no handler call.

## Unit Tests

New file `csharp/tests/RoundLimitTests.cs` (AAA, `Ac<N>_...` names as in `HostileUnpackTests`), using `BinaryPacker.Read` for accepted packets and `BinaryPacker.Unpack` where the handler is observed.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | defaults, constants, `WithLimits()` and `WithLimits(maxRounds: 10)` | 65,535 / 4,194,304; omitted argument is the default |
| AC-2 | 65,535 and 65,536 one-byte `repeat` rounds, defaults | ok with 65,535 entries; `ShortPacket("", 0, 1)`, handler not called |
| AC-3 | `01aabbcc`, `01aabbccdd` with `maxRounds` 3 | ok `[0xaa,0xbb,0xcc]`; `ShortPacket("", 0, 1)` |
| AC-4 | five `times` packets with `maxRounds` 3 | exact shapes listed in AC-4 |
| AC-5 | u32-count `times`: 65,535; 65,536; max count + 65,536 bytes; max count + 65,535 bytes; `01ffffffff00` | ok; `("times", 0, 1)`; `("times", 0, 1)`; `("times", 0, 0)`; `("K", 1, 0)` |
| AC-6 | three-name `repeat`, `maxSlots` 6, three packets | ok; `("", 0, 1)`; `("", 0, 2)` |
| AC-7 | two `times` fields, `maxSlots` 4 and 3 | ok; `("times", 0, 1)` |
| AC-8 | 1 MiB four-name packet, allocation measured | `("", 0, 983041)`, < 128 MiB allocated |
| AC-9 | receiver unchanged; `strict`; dispatch with two schemes | as listed |
| AC-10 | five `WithLimits` calls | four `ArgumentOutOfRangeException` with `ParamName`; one scheme that accepts 65,536 rounds |
| AC-11 | existing suite, unedited (incl. `Ac3_U32TimesCountAboveInt32...`) | green |

Run each new test against the unfixed tree first and require it to fail (AC-2 to AC-8 do: the old code returns no error).

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | default scheme, 65,536 one-byte rounds | `BinaryPacker.Unpack(bytes, scheme.On(h))` | returns `ShortPacket("", 0, 1)`, `h` not called | Reliability |
| AC-4 | `times` scheme, `maxRounds` 3, packet `010409090909` | public `Unpack` | `ShortPacket("times", 0, 1)` | Reliability |
| AC-8 | four-name scheme, 1 MiB | public `Unpack`, allocation measured | `("", 0, 983041)`, < 128 MiB | Performance |
| AC-9 | two handlers of types 1 and 2 | public `Unpack` of a type 2 packet with 3 rounds | `("", 0, 1)` from the type 2 scheme's limit | Reliability |
| AC-11 | existing hostile replay (`HostileVectorTests`) and `Ac3_U32TimesCountAboveInt32...` | `oversize_count_times`, `01ffffffff00` | unchanged results | Compatibility |

## Constraints

- **Owns**: `csharp/**` only (production files named in Problem, plus the new `csharp/tests/RoundLimitTests.cs`). **Forbidden**: `fixtures/**`, `README.md`, `_docs/**`, the other packages, the workflows. The hostile `limit` replay and the `oversize_count_times` widening are AZ-2220, which lands after this task.
- Simplicity (coderule.md): one small limits pair on the scheme, one counter carried by the existing per-call `Scope`; no new class beyond what carries the counter. No static or thread-static state. The counter must not live outside the call (no static), so two calls in parallel do not share it.
- The list element and dictionary value scopes (`Walker.Counted.cs:362`, `:433`) must receive the call's counter, even though no test can reach a round inside an element today (Flagged concerns).
- Files stay under 500 lines (`quality-thresholds.md`): `Walker.Counted.cs` is 460 lines and `Walker.cs` 392; add the check without growing `Walker.Counted.cs` past 500 (split by responsibility if needed).
- Run the formatter and the project's CI-parity typecheck/unit jobs before the commit (`autodev/protocols/ci-parity-gate.md`).
- Canonical test command: `dotnet test` in `csharp/tests`; on this Mac see `_docs/AGENT_GOTCHAS.md` for the host recipes.

## Risks & Mitigation

**Risk 1: Counter lost in a new scope**
- *Risk*: a `new Scope()` that does not receive the call's counter lets rounds in an element bypass the slot total.
- *Mitigation*: AC-7 covers sibling fields; every `new Scope()` on the unpack path is listed in Problem. When AZ-2119 makes round-holding elements reachable, add the element case to this test file.

**Risk 2: Label `""` for `repeat`**
- *Risk*: the refusal of a `repeat` carries the label `""`, which is also the label of an empty-name error elsewhere (`ShortPacket("", 1, 0)` for an empty packet).
- *Mitigation*: `needed` 0 and `left` tell them apart; the label is part of the C15 decision, so it is not invented here.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| D5 (lazy, owner decision 2026-10-06): a `times` count above `maxRounds` is not refused up front; the (maxRounds + 1)th round start is. The first draft (eager) broke `Ac3_U32TimesCountAboveInt32...`; lazy keeps it and bounds memory equally (at most `maxRounds` rounds allocated) | owner (D5) | resolved | Low |
| Round-holding elements: a list or dictionary element with a group of children throws `KeyNotFoundException` on unpack today (AZ-2119), so the "slot total spans list elements" rule cannot be tested; the carrier must still reach those scopes so AZ-2119 does not open a bypass | AZ-2119 owner | open | Low |
| Label of the refusal (`""` for `repeat`, `times` for `times`) and the error kind are interim until C15 | owner (C15) | accepted-risk | Low |
| Public surface grows by one method, two properties, two constants (D1, owner-approved shape recorded as a default) | owner | accepted-risk | Low |
| Allocation per round is dominated by the per-round `Scope` (about 580 bytes), so at the defaults a 37-name body allocates 172 MiB in total; the limits bound it, they do not make it small | owner | accepted-risk | Low |
