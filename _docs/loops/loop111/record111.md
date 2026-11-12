# Autodev loop record - loop 111

loop: 111
branch: dev
plan_artifact: _docs/loops/loop111/plan111.md
tasks_shipped: [AZ-4205]
decisions:
  - owner (2026-11-12): hopper empty, chose "AZ-4199 Lows in C#" from three candidates (sibling probe, C# Lows, C# test hang)
  - owner (2026-11-12): scope "accept all recommended": (1) row form for `E[]`, `IList<E>`, `IDictionary<string, E>`; (2) members of another row type refused at scheme build in element rows and nested rows; (3) `when` and `times` tests pinned to TypeScript bytes; (4) the repeat class to its own cross-package task (AZ-4206), not fixed here
  - agent (new-task Step 5, auto-applied): refusal wording `'Z' is declared for row type Other, but the elements of 'Items' are Mark` / `but the nested row 'M' is Mark`; rounds bound to a collection keep `this scheme is for` (pinned by `RowRoundTests`); base types accepted
measurements:
  - probe on `05bdc52` (scratch console project + TypeScript): members of another row type built and then threw `InvalidCastException` from `Pack` and `Unpack` (element and nested rows); `when` / `times` in an element row: C# = TypeScript (`010200010700`, `01020002050600`); repeat in an element row: C# and TypeScript pack `010200010502` and refuse it on unpack; TypeScript top-level `repeat, u8` packs `01050609` and refuses it
  - new tests on the old `SchemeOrder.cs`: exactly the 3 refusal tests fail; AC-1 does not compile there
  - C# suite 5,384 of 5,384 on `net10.0` and on `netstandard2.0` (5,363 + 21; one review test added after, 103 of 103 element-row and round tests on both targets in the smoke)
  - step 11 `scripts/loop-tests.sh` at `bb99503`: 9 passed (typescript, csharp, dart, cpp, scaffold, cpp-embedded-arm, ring, ac10, publish-gate), 6 skipped as unchanged, 0 failed, 1,014 s, host load 8 to 36; NOT RUN: vcpkg supports and consumer checks (no vcpkg tool on this Mac)
  - smoke: 7/7 (`smoke111.md`)
review: "PASS_WITH_WARNINGS, 5 Low (batch_01_loop111_report.md): 2 fixed (test under a `when`; spec risk text on map-row-only schemes), 2 kept with reasons, 1 no change"
feature_assessment: COMPLETE, round 1 (`assessment111.md`): 10 covered, 1 out of scope (repeat, AZ-4206)
security: lite CLEAN (`_docs/05_security/lite_loop111.md`)
retro: none (next due by loop 113)
leftovers:
  - AZ-4206 (`todo/`, unclaimed): probe the repeat class in all nine packages and give the owner one rule
  - from loop 109 (unchanged): `dotnet test csharp` hang without a console logger; the embedded-arm DNS cause (not reproduced; `diagnose-dns` is the tool); the sibling probe of the AZ-4199 element row in Java, Go, Swift, Rust, Python and C++ was offered this loop and not chosen
  - owner (unchanged): first `dart pub publish`, then automated publishing; the two README lines that say Dart is installed from the repository
  - Jira: AZ-4205 In Testing; AZ-4198, AZ-4199 In Testing (unchanged); the next tag carries AZ-4205
  - from loops 98 to 110 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built; keyserver.ubuntu.com did not answer in loop 105; the autodev rule file `worktree-isolation.md` is outside this repository
smoke: PASS (agent run, owner rule 2026-10-12: 7/7 steps passed; checks in smoke111.md)
smoke_artifact: _docs/loops/loop111/smoke111.md
loop_end_merge: main
