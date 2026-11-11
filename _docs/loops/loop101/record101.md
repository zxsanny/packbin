# Autodev loop record - loop 101

loop: 101
branch: dev
plan_artifact: _docs/loops/loop101/plan101.md
tasks_shipped: [AZ-4168_typescript_colliding_dict_keys]
decisions:
  - owner (2026-11-11): start loop 101 with the TypeScript colliding-key fix, the open TypeScript item of loop 100
  - agent defaults: the refusal is a `RangeError` with Dart's wording (`d: two keys are the same once an unpaired surrogate is written as U+FFFD`); the check compares neighbouring encoded keys after the existing sort; the other six packages are out of scope (not measured); epic AZ-4133 (the Dart package epic, where the finding came from)
measurements:
  - TypeScript: 3,638 tests (3,628 before, plus 10 in `dict-colliding-keys.test.ts`), `tsc --noEmit --strict` clean; 1 source file changed (10 added, 4 removed lines); the new tests fail against the old source (6 of 10)
  - read by running both packages: the 4 colliding dictionaries refused and the 3 others written as before, equal in Dart and TypeScript; 5,000 seeded dictionaries (280 refused): 5,000 same, 0 different
  - 20,000 seeded dictionaries in the TypeScript property test: every packet written unpacks; every refusal is a real collision
  - step 11: typescript (8 s), ring (86 s) and publish-gate (359 s, 8 shares) passed; 12 stages unchanged; run with the loop 99 host environment
review: "one cross-language differential review (5,000 cases) + security lite CLEAN (`_docs/05_security/lite_loop101.md`) + feature assessment round 1 COMPLETE (`assessment101.md`)"
retro: none this loop (complexity 2, no incident); the loop 100 retro is current, next due by loop 104
leftovers:
  - the other six packages (C#, Java, Python, Go, Rust, Swift) may write the same unreadable packet for two dictionary keys that differ only in unpaired surrogates (C# and Java encoders replace a lone half; Go refuses a string that is not valid UTF-8; Swift strings cannot hold one): not measured; one probe per package would show it
  - owner (before the first tag that contains `dart/`; unchanged): publish a first version by hand with `dart pub publish`, then enable automated publishing for `zxsanny/packbin` with tag pattern `v{{version}}`; afterwards edit the two README lines that say Dart is installed from the repository
  - the cross-language differential run of this loop is a scratchpad program (`gen.ts`, `diff.dart`), not committed
  - not run here: the vcpkg supports and consumer checks (no vcpkg tool); a physical board; OIDC token lifetime and pub.dev's answer to a re-publish (unproven until the first tag)
  - the npm package `packbin` 0.4.0 is published without this change; the next tag carries it (a behaviour change for a caller that packed colliding keys; no reader could unpack that packet)
  - from loops 98 to 100 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built
  - Jira: AZ-4168 In Testing (epic AZ-4133 open until the first publish); AZ-4153 and AZ-4134 to AZ-4149 In Testing
smoke: PASS (agent run, owner rule 2026-10-12: 8/8 steps passed at 5bbffd6; checks in smoke101.md)
smoke_artifact: _docs/loops/loop101/smoke101.md
assessment_artifact: _docs/loops/loop101/assessment101.md
loop_end_merge: main
