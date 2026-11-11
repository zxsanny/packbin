# Autodev loop record - loop 103

loop: 103
branch: dev
plan_artifact: _docs/loops/loop103/plan103.md
tasks_shipped: [AZ-4169_csharp_java_lone_surrogate_keys]
decisions:
  - owner (2026-11-11): option A from the loop 102 findings: C# and Java refuse two dictionary keys that become one at pack, as TypeScript and Dart; Java writes U+FFFD (not "?") for an unpaired surrogate, as TypeScript, Dart and C#
  - agent defaults: C# `ArgumentException` (`<field>: two keys are the same once an unpaired surrogate is written as U+FFFD`), Java `IllegalArgumentException` (`dict: two keys ...`), the check compares neighbouring encoded keys after the existing sort; Java encodes each key once; one task of 5 points over two small packages; epic AZ-4133
measurements:
  - C#: `DictCollidingKeysTests` 4 tests (collisions refused, 3 unchanged packets, one lone half, 20,000 seeded dictionaries), 2 of them fail against the old source; 1 source file changed (+8 lines)
  - Java: `DictCollidingKeysTest` (collisions, 3 unchanged packets, a lone half, 12 TypeScript text packets, 20,000 seeded dictionaries); the suite passes (exit 0, 0 FAIL lines) and fails against the old source (13,577 failing checks); one existing check rewritten (the "?" pin of `TextPositionsTest`); 2 source files changed
  - read by running the four packages: TypeScript wrote 5,000 seeded dictionaries (keys over a, b, `?`, the four surrogate halves, U+FFFD, U+FFFF, U+10000, an emoji, `~` and the empty text); C#, Java and Dart each 5,000 same, 0 different, 225 refused
  - step 11: java (18 s), csharp (52 s), ring (134 s), ac10 (5 s) and publish-gate (361 s, 8 shares) passed; 10 stages unchanged
review: "one four-package differential run (5,000 cases) + security lite CLEAN (`_docs/05_security/lite_loop103.md`) + feature assessment round 1 COMPLETE (`assessment103.md`)"
retro: none this loop (no incident); the loop 100 retro is current, due again by loop 104
leftovers:
  - owner (before the first tag that contains `dart/`; unchanged): publish a first version by hand with `dart pub publish`, then enable automated publishing for `zxsanny/packbin` with tag pattern `v{{version}}`; afterwards edit the two README lines that say Dart is installed from the repository
  - the published packages (npm 0.4.0, NuGet and Maven Central 0.4.0) do not have the loop 101 and 103 changes; the next tag carries them (a behaviour change for a caller that packed colliding keys or a lone surrogate in Java)
  - the four-package differential is run by hand from `_docs/02_task_plans/csharp-java-lone-surrogate-keys/differential/` and by the loop 103 smoke script, not by `loop-tests.sh`
  - the loop 102 smoke script asserts the pre-loop-103 behaviour of C# and Java and is not expected to pass on a later HEAD (noted in `probes/README.md`)
  - not run here: the vcpkg supports and consumer checks (no vcpkg tool); a physical board; OIDC token lifetime and pub.dev's answer to a re-publish (unproven until the first tag)
  - from loops 98 to 102 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built
  - Jira: AZ-4169 In Testing (epic AZ-4133 open until the first publish); AZ-4168, AZ-4153 and AZ-4134 to AZ-4149 In Testing
smoke: PASS (agent run, owner rule 2026-10-12: 8/8 steps passed at dd2bd19; checks in smoke103.md)
smoke_artifact: _docs/loops/loop103/smoke103.md
assessment_artifact: _docs/loops/loop103/assessment103.md
loop_end_merge: main
