# Feature assessment — loop 119 (AZ-4253)

round: 1
verdict: COMPLETE — 8 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

| angle | spec | evidence (test; code path) | status |
|-------|------|----------------------------|--------|
| element row of a list | AC-1 | `RowClassTest.ac1ElementRowOfAListIsRefused`; `Packbin.group` → `RowClassCheck` | covered |
| element row of a dict | AC-1 | `ac1ElementRowOfADictIsRefused` | covered |
| nested row | AC-2 | `ac2NestedRowIsRefused` | covered |
| under flags, flag bit, when, anchored group, times, a nested row's own accessors | AC-3 | `ac3MembersInsideContainersAreRefused` (six cases) | covered |
| base-class member builds, same bytes, reads back | AC-4 | `ac4BaseClassMembersBuildAndRoundTrip` | covered |
| another accessor failure on an empty child still builds | AC-5 | `ac5OtherAccessorFailuresStillBuild` | covered |
| factory returning `null` builds as before (found in implementation) | AC-6 | `TypedNestedRowTest.nullFactory` unchanged and green | covered |
| nothing else changes: suite, probe | AC-6 | `java/test.sh` green; probe diff = 2 lines | covered (step 11 re-checks) |
| a top-level typed row member of another class (found in review) | — | outside the item (element and nested rows); hygiene entry `java-top-level-row-class` | out-of-scope |

Discoveries read: `implementation_report_java-element-row-raw-class-cast_loop119.md` (three rows, handled), `reviews/batch_01_loop119_review.md`.
