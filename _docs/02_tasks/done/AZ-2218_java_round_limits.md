# Java unpack refuses rounds above the scheme's limits

**Task**: AZ-2218_java_round_limits
**Name**: Java round and slot limits on unpack
**Description**: A Java `Scheme` carries `maxRounds` and `maxSlots` (defaults 65,535 and 4,194,304); an unpack that would create more rounds or slots is refused with the interim bad-value error when the round that crosses a limit would start, and a caller can raise or lower the limits per scheme with `withLimits`.
**Complexity**: 3 points
**Dependencies**: None (the shared hostile case and the README are AZ-2220, which lands after this task)
**Component**: java
**Tracker**: AZ-2218
**Epic**: AZ-2069

## Problem

Loop 15, finding F10 (`_docs/05_security/security_report.md`), owner option A, decisions D1 to D7 in `_docs/02_task_plans/unpack-limits-and-ci-hardening/problem.md`.

Unpack of a `repeat` or `times` round has no budget. Facts on the current code (`b45335d`):

- `Rounds.unpackRepeat` (`Rounds.java:46-60`) loops `while (offset[0] < data.length)`; `Rounds.unpackTimes` (`:62-77`) loops a `long` count (called from `VarFields.unpackTimes`, `VarFields.java:327-334`). Each round runs `unpackRound` (`:84-102`), which adds one `null` entry to every value field the round skipped (`:95-100`; the fields come from `values(...)`, `:121-143`). A round must read at least one byte, so rounds are bounded only by the bytes left.
- Cost: a 1 MiB packet of one-byte rounds with a 36-name `when` body is about 570 MB peak (audit; README `README.md:1081`).
- The only defence today is the README sentence "cap the packet length where you read it".
- The unpack entry point cannot take an extra argument: `BinaryPacker.unpack(byte[], Scheme.Handler<?>...)` (`BinaryPacker.java:19`) goes to `dispatch` (`:42`) and `decode(matched.scheme, data)` (`:51-72`), which calls `Walker.unpackFields(scheme.fields, data, offset, row, new HashMap<>(), false)` (`:63`). So the limits live on the scheme (D1).
- `Scheme<T>` (`Scheme.java:8-37`) is a final class with final fields, built by `new Scheme<>(typeNumber, Class<T>, Field...)`, a varargs constructor that validates through `SchemeOrder.validate`.
- There is no per-call object. Unpack threads `(data, offset, row, seen, asList)` through every method: about 25 methods take `int[] offset` (`Walker.java` 9, `VarFields.java` 6, `Containers.java` 6, `Rounds.java` 3, `BinaryPacker.java` 1). `seen` cannot carry a counter: list and dict elements start new `seen` maps (`Containers.java:184`, `:191-192`). A per-call slot total therefore needs a new parameter, or `int[] offset` replaced by a small per-call cursor object; either touches all those methods (mechanical).
- A round-holding list element is reachable in Java: a list whose element is a group holding a `times` unpacks today (checked in a scratch run), so the slot total must span list elements.
- Error mechanism: unpack returns `null` for ok, else `Packbin.ShortPacket(field, needed, left)`, `TrailingBytes` or `TypeMismatch`. The zero-width `times` round already returns `new Packbin.ShortPacket(field.label(), 0, data.length - before)` (`Rounds.java:73`). `Field.label()` (`Field.java:94-99`) is `"times"` for `times` and the anchor id as a string for the others (`repeat` 0 gives `"0"`). C15 (a real error kind and label) is the owner's open decision, so the refusal uses this error.
- The existing `RepeatRoundTest.paddingIsLinear` (`RepeatRoundTest.java:80`) unpacks a 65,536-byte packet: type + exactly 65,535 one-byte rounds, equal to the default `maxRounds`, so it must keep passing (at the limit, not above it).

## Outcome

- A scheme has `maxRounds` (default 65,535) and `maxSlots` (default 4,194,304). `withLimits(...)` returns a scheme with other values; the receiver is unchanged.
- An unpack that would start more than `maxRounds` rounds of one `repeat` or `times` field, or whose rounds together would hold more than `maxSlots` slots, returns `ShortPacket(label, 0, left)`, the handler is not called, no row is visible.
- A refused 1 MiB packet does work bounded by the limits, not by the packet length.
- A packet at or below the limits unpacks exactly as before. Pack, wire bytes and result shapes do not change.

## Public surface (the names the implementer must use)

- `Scheme.DEFAULT_MAX_ROUNDS` (`public static final int` 65_535) and `Scheme.DEFAULT_MAX_SLOTS` (`public static final long` 4_194_304L).
- `scheme.maxRounds()` (`int`) and `scheme.maxSlots()` (`long`).
- `scheme.withLimits(int maxRounds, long maxSlots)` returns a new `Scheme<T>` with the same type number, class and (already validated) fields. Both arguments are given (Java has no optional arguments); pass the constant to change only one.
- Construction error (D6): `maxRounds < 1` or `maxSlots < 1` throws `IllegalArgumentException` whose message names `maxRounds` or `maxSlots`, the type the type-number check uses (`Scheme.java:16`). No "unlimited" value: `Integer.MAX_VALUE` and `Long.MAX_VALUE` are valid.

## What is counted and when it is checked (D2, D5)

- Rounds: the rounds one `repeat` or `times` field starts in one walk of that field.
- Slots: for each round started, the number of fields `values(field.children)` returns (the fields that get one entry per round), added to one total shared by every field of the unpack call, including fields in list and dict elements and nested rows.
- `repeat`: at the start of a round (only when bytes are left), refuse if the field has already started `maxRounds` rounds or if total slots + this round's fields > `maxSlots`.
- `times`: the same check at the start of each round: refuse the (`maxRounds` + 1)th round, or a round that would take total slots above `maxSlots`. The count field is not refused up front (D5, lazy, 2026-10-06): a huge count whose packet ends early gives today's short read.
- `left` is `data.length - offset[0]` at the refusal (`data` includes the type byte).
- Label (D4): `field.label()`, as the zero-width `times` round: `"times"` for `times`, the anchor id for `repeat`.

## Scope

### Included
- `Scheme`: the two limits, `withLimits`, the defaults, validation; passing them from `BinaryPacker.decode` to the walker.
- The refusal in `Rounds.unpackRepeat` and `Rounds.unpackTimes`, with the per-call slot total carried through every unpack method (list and dict elements included).
- New tests (below). No existing test changes (AC-11).

### Excluded
- Pack, wire bytes, result shapes, session and dispatch behavior (D7); list and dict counts; `bits` and `packed`.
- A distinct error kind (C15), the README, the hostile case and the docs (AZ-2220).
- C++ and Python.

## Acceptance Criteria

**AC-1: Defaults and surface**
Given any scheme built as today, and `scheme.withLimits(10, Scheme.DEFAULT_MAX_SLOTS)`
When `maxRounds()`, `maxSlots()`, `Scheme.DEFAULT_MAX_ROUNDS` and `Scheme.DEFAULT_MAX_SLOTS` are read
Then the first has 65,535 and 4,194,304; the constants have those values; the second has 10 and 4,194,304.

**AC-2: `repeat` at the default limit**
Given `Maps.scheme(1, Packbin.repeat(0, Packbin.u8(0, Access.get("k"), Access.set("k"))))`
When a packet of type `01` followed by 65,535 one-byte rounds, and one followed by 65,536 rounds, are unpacked
Then the first returns `null` and `k` has 65,535 entries; the second returns `ShortPacket("0", 0, 1)` and the handler is not called.

**AC-3: `repeat` refused at the (maxRounds + 1)th round**
Given the scheme of AC-2 with `withLimits(3, Scheme.DEFAULT_MAX_SLOTS)`
When `01aabbcc` and `01aabbccdd` are unpacked
Then the first returns `null` and `k` is `[170, 187, 204]`; the second returns `ShortPacket("0", 0, 1)` (refused when round 4 would start, `dd` unread).

**AC-4: `times` refused at the (maxRounds + 1)th round**
Given `Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "k")))` with `withLimits(3, Scheme.DEFAULT_MAX_SLOTS)`
When `0103090909`, `010409090909`, `0104090909`, `01ff09` and `01030909` are unpacked
Then: `null` with `k` `[9, 9, 9]` and `n` 3; `ShortPacket("times", 0, 1)` (round 4 would start with one byte left); `ShortPacket("times", 0, 0)` (count 4, three rounds present: refused when round 4 would start, before the short read of `k` the old code returns); `ShortPacket("1", 1, 0)` (count 255, one round present: the limit is never reached, today's short read); and `ShortPacket("1", 1, 0)` (count 3, two rounds present: unchanged).

**AC-5: `times` at the default limit**
Given `u32 n; times(1, 0, u8 k)` and the default limits
When a packet with `n` = 65,535 followed by 65,535 bytes, one with `n` = 65,536 followed by 65,536 bytes, one with `n` = 4,294,967,295 followed by 65,536 bytes, one with `n` = 4,294,967,295 followed by 65,535 bytes, and `01ffffffff00` are unpacked
Then: `null` with `k` of 65,535 entries; `ShortPacket("times", 0, 1)`; `ShortPacket("times", 0, 1)`; `ShortPacket("times", 0, 0)`; and `ShortPacket("1", 1, 0)` (count 4,294,967,295, one round present: today's short read, unchanged).

**AC-6: Slot limit**
Given `repeat(0, u8(0, "k"), when(1, eq(0, 1), u8(1, "a"), u8(2, "b")))` (three fields: k, a, b) with `withLimits(Scheme.DEFAULT_MAX_ROUNDS, 6)`
When `010000`, `01000000` and `0100000000` are unpacked
Then the first returns `null` with `k` `[0, 0]` and `a`, `b` `[null, null]` (2 rounds x 3 = 6, exactly the limit); the second returns `ShortPacket("0", 0, 1)`; the third `ShortPacket("0", 0, 2)` (both refused when round 3 would start).

**AC-7: The slot total is per unpack call, across fields and list elements**
Given (a) `u8 n; times(1, 0, u8 k); times(2, 0, u8 v)` with packet `0102aabbccdd`, and (b) `list(xs, group(0, u8 n, times(1, 0, u8 v)))` with packet `01` `0200` `020708` `02090a` (two elements of two rounds each)
When (a) is unpacked with `withLimits(3, 4)` and `withLimits(3, 3)`, and (b) with `withLimits(3, 4)`, `withLimits(3, 3)` and `withLimits(1, Scheme.DEFAULT_MAX_SLOTS)`
Then (a): `null` with `{n: 2, k: [170, 187], v: [204, 221]}`; `ShortPacket("times", 0, 1)`. (b): `null` with `xs` of two elements `{n: 2, v: [7, 8]}` and `{n: 2, v: [9, 10]}`; `ShortPacket("times", 0, 1)` (refused when round 2 of the second element's `times` would start: the total spans elements); `ShortPacket("times", 0, 4)` (`maxRounds` 1: round 2 of the first element's `times` would start with four bytes left).

**AC-8: A refused 1 MiB packet is bounded by the limits**
Given a `repeat` of `u8 k` and a `when` with 36 more fields (alternating `u8`, `u16`; 37 fields in all) and the default limits
When a packet of type `01` followed by 1,048,576 zero bytes is unpacked
Then it returns `ShortPacket("0", 0, 983041)` (refused at round 65,536: the rest was not walked) and the handler is not called. The packet of 65,535 rounds returns `null`. The old code returns `null` for the 1 MiB packet, so the test fails on the unfixed tree.

**AC-9: Limits belong to the scheme**
Given `base` (default limits), `strict = base.withLimits(3, Scheme.DEFAULT_MAX_SLOTS)`, and `other` of type 2 built with `withLimits(2, Scheme.DEFAULT_MAX_SLOTS)`
When `01aabbccdd` is unpacked with `base.on(...)`, then with `strict.on(...)`, and `02aabbcc` is unpacked with `base.on(...)` and `other.on(...)` in one call
Then the first returns `null` with four entries in `k` (the receiver kept its limits); the second returns `ShortPacket("0", 0, 1)`; the third returns `ShortPacket("0", 0, 1)` from `other`'s limit.

**AC-10: Invalid limits are refused at construction**
Given any scheme
When `withLimits(0, 1)`, `withLimits(-1, 1)`, `withLimits(1, 0)`, `withLimits(1, -1)` and `withLimits(Integer.MAX_VALUE, Long.MAX_VALUE)` are called
Then the first four throw `IllegalArgumentException` naming `maxRounds` or `maxSlots`, and the last returns a scheme that unpacks the 65,536-round packet of AC-2.

**AC-11: Nothing else changes**
Given the existing Java tests
When `java/test.sh` runs
Then every test passes without an edit, including `HostileUnpackTest.java:157-160` (`expectShort("AC-3 u32 max times", u32Times, "01ffffffff00", "1", 0)`: round 1 starts, round 2 never does, so the short read stays), `RepeatRoundTest.paddingIsLinear` (65,535 rounds), the zero-width tests and the `oversize_count_times` vector replay, and `api-check.sh` still passes. No hostile vector and no test assertion changes.

## Non-Functional Requirements

**Performance**
- One comparison per round start and per `times` count; the existing suite time does not grow. A refused 1 MiB call took 97 ms in a scratch run.

**Compatibility**
- A packet with more than 65,535 rounds, or more than 4,194,304 slots, that unpacked before is refused until the scheme raises the limit (upgrade note in AZ-2220). No existing Java test and no README example reaches either default (all four Java test mains pass against a scratch prototype of this lazy design).
- Main sources keep to Android API 26 (`java/api-check.sh`) and compile with `--release 17`.

**Reliability**
- A refusal returns an error value; no exception, no partial row, no handler call.

## Unit Tests

New file `java/src/test/java/packbin/RoundLimitsTest.java` with `static void run()` called from `PackbinTest.run` next to `RepeatRoundTest.run()` (`PackbinTest.java:48`); it uses the existing `Maps`, `Access`, `HostileRun` helpers and `PackbinTest.expectEq`/`expectTrue`/`expectThrows`.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | defaults, constants, `withLimits(10, DEFAULT)` | 65,535 / 4,194,304; the given values |
| AC-2 | 65,535 and 65,536 one-byte `repeat` rounds, defaults | `null` with 65,535 entries; `ShortPacket("0", 0, 1)`, handler not called |
| AC-3 | `01aabbcc`, `01aabbccdd` with `maxRounds` 3 | `k` `[170, 187, 204]`; `ShortPacket("0", 0, 1)` |
| AC-4 | five `times` packets, `maxRounds` 3 | exact shapes in AC-4 |
| AC-5 | u32-count `times`: 65,535; 65,536; max count + 65,536 bytes; max count + 65,535 bytes; `01ffffffff00` | `null`; `("times", 0, 1)`; `("times", 0, 1)`; `("times", 0, 0)`; `("1", 1, 0)` |
| AC-6 | three-field `repeat`, `maxSlots` 6, three packets | `null`; `("0", 0, 1)`; `("0", 0, 2)` |
| AC-7 | two `times` fields, and a list of group elements each with a `times` | totals and shapes in AC-7 |
| AC-8 | 1 MiB, 37-field body, defaults | `("0", 0, 983041)`; 65,535 rounds `null` |
| AC-9 | receiver unchanged; `strict`; dispatch with two schemes | as listed |
| AC-10 | five `withLimits` calls | four `IllegalArgumentException`; one scheme accepting 65,536 rounds |
| AC-11 | existing suite, unedited (incl. `AC-3 u32 max times`) | green |

Run each new test against the unfixed tree first and require it to fail (AC-2 to AC-8 do).

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | default scheme, 65,536 one-byte rounds | `BinaryPacker.unpack(bytes, scheme.on(h))` | returns `ShortPacket("0", 0, 1)`, `h` not called | Reliability |
| AC-4 | `times` scheme, `maxRounds` 3, `010409090909` | public `unpack` | `ShortPacket("times", 0, 1)` | Reliability |
| AC-7 | list of group elements each with `times` | public `unpack`, `withLimits(3, 3)` | `ShortPacket("times", 0, 1)` | Reliability |
| AC-8 | 37-field scheme, 1 MiB | public `unpack`, elapsed time | `("0", 0, 983041)`, under 1 s | Performance |
| AC-9 | two handlers of types 1 and 2 | public `unpack` of a type 2 packet with 3 rounds | `("0", 0, 1)` from the type 2 scheme's limit | Reliability |
| AC-11 | existing `HostileVectorTest` and `HostileUnpackTest` | `oversize_count_times`, `01ffffffff00` | unchanged results | Compatibility |

## Constraints

- **Owns**: `java/**` only (production files named in Problem, the new `RoundLimitsTest.java`, its call in `PackbinTest.java`). **Forbidden**: `fixtures/**`, `README.md`, `_docs/**`, the other packages, the workflows. The hostile `limit` replay is AZ-2220, which lands after this task.
- Simplicity (coderule.md): two numbers on the scheme and one per-call counter; no new interface or hierarchy. No static or thread-local state: two unpack calls in parallel must not share a counter.
- The counter must reach list and dict elements (`Containers.java:184-192`): AC-7 (b) is the test.
- Files stay under 500 lines (`quality-thresholds.md`); `Walker.java` is the largest touched file.
- Test command: `java/test.sh`; run `api-check.sh` (it downloads three pinned jars) and the CI-parity jobs before the commit.

## Risks & Mitigation

**Risk 1: Signature churn**
- *Risk*: threading a per-call object touches about 25 methods and may hide a slip (an element scope that drops the counter).
- *Mitigation*: AC-7 (b) covers list elements; take the smallest change (one new parameter, or a cursor object in place of `int[] offset`); the compiler finds every call site.

**Risk 2: Label of a refused `repeat`**
- *Risk*: the label is the anchor id (`"0"`), which is also the label of a short read of field 0.
- *Mitigation*: `needed` 0 tells them apart; same convention as the zero-width `times` error; the label is part of the C15 decision.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| D5 (lazy, owner decision 2026-10-06): a `times` count above `maxRounds` is not refused up front; the (maxRounds + 1)th round start is. The first draft (eager) broke `HostileUnpackTest.java:157-160`; lazy keeps it and bounds memory equally | owner (D5) | resolved | Low |
| The per-call counter needs a signature change across about 25 methods (see Problem); if it grows beyond a mechanical change the task should be split (carrier first, limits second) | implementer | open | Low |
| Label of the refusal (anchor id for `repeat`, `times` for `times`) and the error kind are interim until C15 | owner (C15) | accepted-risk | Low |
| Public surface grows by one method, two accessors, two constants (D1, shape recorded as a default) | owner | accepted-risk | Low |
