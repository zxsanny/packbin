# Batch review — loop 118, batch 01 (AZ-4251)

verdict: PASS_WITH_WARNINGS
scope: `csharp/Walker.Presence.cs` (`BitOn`), `csharp/tests/FlagsInFlagsTests.cs`, `scripts/probes/flags-in-flags/` (new); comment-only path updates of the gotchas split (`.github/workflows/ring-prepare.sh`, `.github/workflows/publish-vcpkg.test.sh`, `cpp/embedded/lib.sh`, `rust/embedded/limits-m33f.txt`)
reviewer: the parent (`/code-review`, high)

| # | severity | category | finding | outcome |
|---|----------|----------|---------|---------|
| 1 | Low | Test coverage | the split flag-byte form (`FlagByte().Bit(Flags(...))`, `FlagGroup.Compute`) goes through the same `BitOn` and had no test | fixed: `PackAndUnpack_SplitFlagByte_*` (four shapes); fails 2 of 4 on the old code |
| 2 | Low | Test coverage | Python, Go, Swift and Dart are probed in their map-row form only | kept: stated in the probe README and the findings file |

Checks: the other C# switches over field kinds (`FirstName`, `FirstGiven`, `DroppedBody`, `AddOptionalNames`, `AddRoundNames`, `ChildPresent`) already have a `Flags` arm; only `BitOn` lacked it. `shellcheck` clean on the 10 probe scripts. Proving runs: the new tests fail on the old `BitOn` (5 of 13, then 2 of 6 for the split form); the C# probe prints `0102 differs` for `both` on the old code.
