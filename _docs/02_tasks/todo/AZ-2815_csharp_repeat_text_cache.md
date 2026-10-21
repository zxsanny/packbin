---
loop: 54
branch: dev
---

# C# text: reuse the previous round's encoded bytes in a times/repeat pack

**Task**: AZ-2815_csharp_repeat_text_cache
**Name**: C# repeated-text reuse
**Description**: A pack call keeps the encoded field of the last text it wrote and writes it again when the next round's text is equal, so 200 rounds of one 65,535-character text take a few milliseconds, not 1 s.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `csharp/Walker.Counted.cs` (`PackUtf8`), `csharp/PackOut.cs`, `csharp/tests/CompactTextTests.Repeat.cs`
**Tracker**: AZ-2815
**Epic**: AZ-2645

## Problem

`CompactTextTests+RepeatedTextSpeed` (AZ-2737, CS-D7) failed on `main` in loop 49 (run 39384081368: 1.083 s and 1.015 s) and loop 53 (run 39537652411: 1.070 s and 1.023 s), in the `netstandard2.0` step, at load factor 1.00, so at a strict 1.000 s. `dev` was green both times. On this Mac the test takes 0.89 to 1.00 s: the C# pack runs the whole text parse in every round (about 5 ms each) and has no headroom against its own bound. Java, Python, TypeScript, Go, Swift and Rust keep the previous round's encoded text for the rest of the pack call.

## Outcome

- The existing test (1 s nominal, load-aware) passes with at most 250 ms measured idle, 10 of 10 runs, on both targets, typed and dictionary.
- Every packet stays byte-identical; a changed text is encoded again; nothing outlives a pack call.

## Scope

### Included
- Keep the last text's bytes and its encoded field for the rest of one pack call and reuse them when the next text's UTF-8 bytes are equal.
- Tests: changed text mid-run, alternating texts, two texts of equal length differing in the last character, a compacting text and a raw text, two calls in a row, the 65,536-byte refusal.
- Record the measured times (idle, both targets) in the batch report.

### Excluded
- Any other package, any wire change, any public API change.
- The dictionary-key encode in `Walker.Collections.cs` (keys are short and distinct).

## Acceptance Criteria

**AC-1: Headroom** (AC-C1)
Given 200 rounds of one 65,535-character text in a `times` pack
When the C# repeat test runs on an idle host, on the default target and on `PackbinTarget=netstandard2.0`, typed and dictionary
Then pack plus unpack finish within 1 s nominal times the load factor, and within 250 ms in 10 of 10 consecutive runs.

**AC-2: Same bytes** (AC-C2)
Given the whole C# suite and every `enc` row of `fixtures/text/vectors.txt`
When they run before and after the change on both targets
Then 0 packets differ and all 4,228 tests pass.

**AC-3: Changed text** (AC-C3)
Given 200 rounds with the text changed at round 100, alternating texts A, B, A, B, and two texts of equal length that differ only in the last character, each with a compacting and a raw text
When the packets are built
Then each equals the packet made by encoding every round's text one by one (0 differing bytes).

**AC-4: Nothing outlives a call** (AC-C4)
Given two pack calls in a row (same text, then a different text) and two threads packing at once
When both finish
Then each packet equals the one-by-one encoding (0 differing bytes) and the existing concurrency test passes.

**AC-5: Limit unchanged** (AC-C5)
Given a text of 65,536 UTF-8 bytes
When it is packed
Then it is refused with today's message.

## Non-Functional Requirements

**Performance**
- No other C# text case gets slower (the speed suite shows the same or better times).

**Reliability**
- No state outside the pack call (no static, no instance field of the scheme).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the existing repeat test, plus a recorded idle time loop | pass; at most 250 ms |
| AC-3 | `CompactTextTests.Repeat` new facts (mid-run change, alternation, last-character change, compacting, raw) | packets equal the uncached encoding |
| AC-4 | two calls in a row; the existing concurrency test | pass |
| AC-5 | 65,536-byte text | same refusal message |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` and the same with `-p:PackbinTarget=netstandard2.0` | whole suite | 0 failures | Performance |
| AC-2 | `bash .github/workflows/language-pair.sh` (host recipes of `AGENT_GOTCHAS.md`) | cross-language ring | "language pairs passed" | — |

## Constraints

- `MSBUILDDISABLENODEREUSE=1` on every `dotnet test` (`AGENT_GOTCHAS.md`).
- The cache is per pack call, as in Java: it lives in the object one pack call owns.

## Risks & Mitigation

**Risk 1: A stale reuse writes the wrong text**
- *Risk*: equal length, equal prefix, different last character is taken for equal.
- *Mitigation*: compare the whole UTF-8 byte arrays; AC-3 has the last-character case.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The `main`-only failure pattern is unexplained (runner noise is a guess) | the fix removes the near-miss on every runner; the next two `main` runs are read after the push | accepted-risk | Low |
