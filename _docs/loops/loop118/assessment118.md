# Feature assessment — loop 118 (AZ-4251)

round: 1
verdict: COMPLETE — 9 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

| angle | spec | evidence (test; code path) | status |
|-------|------|----------------------------|--------|
| both values, typed (scenario 1) | AC-1 | `FlagsInFlagsTests.Pack_TypedRow_*` / `Unpack_TypedRow_*` (`01030109`); `Walker.BitOn` `Flags` arm via `PackFlags` | covered |
| x only, b only, none (scenarios 2-4) | AC-2 | same theories, four rows | covered |
| dictionary form (scenario 5) | AC-1 | `Pack_Dictionary_*` | covered |
| three levels (scenario 8) | AC-3 | `PackAndUnpack_ThreeLevels_*` (`0101010109`) | covered |
| split flag byte (`FlagByte().Bit(Flags(...))`), found in the review | AC-1 (same rule) | `PackAndUnpack_SplitFlagByte_*`; `FlagGroup.Compute` → `BitOn` | covered |
| a packet C# wrote before (scenario 6) | constraint | the unpack path is unchanged (the `Unpack_TypedRow_*` rows read the TypeScript bytes, which old C# also read); no other package changes bytes (probe) | covered |
| nine packages (scenario 7) | AC-4, AC-5 | `scripts/probes/flags-in-flags/run.sh`, 40 lines `same`, two identical runs; `_docs/06_metrics/flags-in-flags-probe_2026-11-13.md` | covered |
| a sibling differs → one decision | AC-5 | none differs; no decision row needed | covered |
| suite on both targets | AC-6 | 5,491 passed on `net10.0` and the `netstandard2.0` build; step 11 repeats it in the CI container | covered (step 11 re-checks) |

Discoveries read: `implementation_report_csharp-flags-in-flags-presence_loop118.md` (one row, the split form, handled), `reviews/batch_01_loop118_review.md` (finding 2 kept: four packages probed in map-row form only, stated in the probe README).

## Not walked

- An inner `flags` that holds a `when`, `times`, `repeat` or a nested row: the arm reuses `AnyChildPresent` → `ChildPresent`, the same member rules a group inside a `flags` uses, which `FlagsWhenMemberTests`, `FlagsRoundMemberTests` and `NestedRowFlagByteTests` pin; no behaviour of this loop is new there.
