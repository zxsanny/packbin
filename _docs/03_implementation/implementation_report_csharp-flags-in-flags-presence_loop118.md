# Implementation report — C# flags in flags, loop 118

task: AZ-4251 (3 points), one batch. C# fix and tests by the parent; the nine-package probe by one worker (`scripts/probes/flags-in-flags/` only), the C# probe run by the parent.

Delivered: `csharp/Walker.Presence.cs` `BitOn` gets a `Flags` arm (a `flags` is on when any member is on, as TypeScript's `bitOn`); `csharp/tests/FlagsInFlagsTests.cs` (17 tests: four shapes typed pack, typed unpack, dictionary pack, split flag byte; three levels); `scripts/probes/flags-in-flags/`; findings `_docs/06_metrics/flags-in-flags-probe_2026-11-13.md`.

Result in one line: C# was the only package that dropped the inner value; after the fix all nine pack `01030109`, `01010109`, `0102`, `0100` and read them back (40 lines `same`, two runs 29 s and 26 s, byte-identical).

Tests: C# suite 5,491 tests, 0 failed, on `net10.0` and on the `netstandard2.0` build (after the review fix). CI-parity: the C# suite on both targets (`dotnet test csharp/tests`, `-p:PackbinTarget=netstandard2.0`).

## Discovered during implementation

| spec ref | finding | proposed handling | clear/unclear |
|----------|---------|-------------------|---------------|
| AC-1 | the split flag-byte form (`FlagByte().Bit(Flags(...))`) dropped the inner value too (same `BitOn`) | pinned by four more tests in the same file; same fix | clear |

Review: `reviews/batch_01_loop118_review.md` (PASS_WITH_WARNINGS, 1 fixed, 1 kept).
