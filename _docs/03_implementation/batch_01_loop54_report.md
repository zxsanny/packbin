# Batch Report

**Batch**: 1 (loop 54)
**Tasks**: AZ-2815_csharp_repeat_text_cache
**Date**: 2026-10-21

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2815_csharp_repeat_text_cache | Done | 3 source files (`csharp/PackOut.cs`, `csharp/Walker.Counted.cs`, new `csharp/tests/CompactTextTests.RepeatReuse.cs`) | 4,234 of 4,234 on both targets | None |

## Code Review Verdict: not run per batch

Owner rule (memory `one-total-review-and-test`): one total review and one step-11 run per loop. The mutant check below stands in for the batch.

## Evidence

- Cause read from the CI log of `main` run 39537652411 (job `suites (csharp rust)`, second dotnet step, `netstandard2.0`): `RepeatedTextSpeed.Ac1_LoneText_65535CharactersIn200Rounds…` 1.070 s (dictionary) and 1.023 s (typed) against 1.000 s at load factor 1.00; the same test failed the same way in run 166 (loop 49: 1.083 s and 1.015 s).
- Before the change on this Mac (load factor 2.4): 893 to 1,002 ms, both targets, both variants.
- After: 24 to 36 ms in 20 of 20 runs (10 per target, 2 variants), pack part 17 to 26 ms. AC-1 asks for at most 250 ms: seven times the room.
- `PackOut.EncodeText` keeps the last text's UTF-8 bytes and its field for one pack call (the object ends with the call); equal bytes reuse the field. The call site is `PackUtf8` only; the dictionary-key encode stays as is.
- Mutant (reuse without comparing the text, in `PackOut.cs`): 5 of the 6 new facts fail; restored.
- AC-5 (65,536-byte refusal) is the existing `Ac5_Pack_65535Bytes_IsAcceptedAnd65536Refused`; AC-4 concurrency is the existing `CompactTextTests.Concurrency` plus the new two-calls-in-a-row fact.

## Test Suite

- Total: 4,234 (4,228 before, 6 new)
- Passed: 4,234 on the default target and on `PackbinTarget=netstandard2.0`
- Failed: 0
- Skipped: 0

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The loop 46 record said C# "met 1 s unchanged" from an idle run on a host at load factor 2.4; the CI runner reads load factor 1.00 because the factor is clamped to at least 1, so the same code sat at the bound there | AZ-2815 AC-1 | a speed test whose idle time is within 10% of its bound is a latent CI failure; the 250 ms headroom line of AC-C1 is the guard. The other seven packages' repeat tests were not timed against their CI bound in this loop | clear (the CI log lines above) |
| 2 | Only `main` failed in both loops, never `dev` | AZ-2815 flagged concern | cause unproven; read the next two `main` runs after the push | unclear (no evidence) |

## Commit

`[AZ-2815] C# pack reuses the previous round's encoded text` · `Loop: 54`

## Next Batch: AZ-2816
