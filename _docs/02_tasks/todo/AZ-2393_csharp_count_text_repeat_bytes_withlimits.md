---
loop: 21
branch: dev
---

# C#: count above int.MaxValue text, lone byte[] in a repeat, WithLimits overload

**Task**: AZ-2393_csharp_count_text_repeat_bytes_withlimits
**Name**: C#: count above int.MaxValue text, lone byte[] in a repeat, WithLimits overload
**Description**: Pin the C# error text for a count above `int.MaxValue`, a lone `byte[]` in a `repeat`, and add a `WithLimits` overload so the added optional parameter is not a binary break.
**Complexity**: 2 points
**Dependencies**: AZ-2373 (same worker, runs after it)
**Component**: csharp
**Tracker**: AZ-2393
**Epic**: AZ-2069

## Problem

Gaps G4 (A5, A6) and A7 of the loop 20 review. The C# text for a count above `int.MaxValue` and the behavior of a lone `byte[]` in a `repeat` are untested; the optional `maxBytes` parameter of `WithLimits` is a binary break for callers compiled against loop 19.

## Outcome

- Both behaviors pinned by tests; `WithLimits` keeps the old signature as an overload.

## Scope

### Included
- `csharp/`.

### Excluded
- Other packages.

## Acceptance Criteria

**AC-1: count text**
Given a count above `int.MaxValue`
When packed
Then the pinned error text

**AC-2: lone byte[] in repeat**
Given a lone `byte[]` in a `repeat`
When packed
Then the pinned outcome

**AC-3: binary compatible**
Given the old `WithLimits(maxRounds, maxSlots)` call
When compiled and run
Then it resolves

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | count text | equal |
| AC-2 | byte[] in repeat | equal |
| AC-3 | old overload | resolves |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | none | unit tests only | - | — |

## Constraints

- Upgrade note in the README (step 13).

## Loop 21 result

C# pins the count text above `int.MaxValue` (`Out: count 'U' is 3000000000, which does not fit an int`; `times: count ...` for a `times`), the lone `byte[]` in a `repeat` (`'Raw': a round's value belongs in a list with one entry per round; wrap this value in a list`, with the `maxRounds` text first when the buffer is longer than the limit) and a `byte[]` for a scalar name (one round per byte). `Scheme<T>.WithLimits(int, long)` is an overload again. Test: `CountTextAndLimitsTests`. README: the loop 21 C# paragraph.
