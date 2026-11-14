# Feature assessment — loop 127 (AZ-4306 to AZ-4308, hygiene)

verdict: COMPLETE
assess_round: 0

Intent (owner: "Run hygiene loop"): do the nine entries of `hygiene.md` that are small; two are split out as not small.

| entry | covered by | status |
|-------|-----------|--------|
| 2 C# test file over 500 lines | `HostilePackVectorTests.cs` 509 to 280 + 237, same count | done |
| 3 Rust times/repeat before the depth check | `round_depth_tests.rs`: 1,000 / 5,000 / 50,000 refused; 50,000 overflowed before | done |
| 4 shared Field measured once | six packages (Java already); 60-level diamond refused in ms; the walks before the id check also memoised in Dart, Swift, Go | done; nested-row diamond left (hygiene) |
| 6 Dart flag-byte bit test | `scheme_depth_shared_test.dart`, proved against `flagBit` counted | done (nearest nestable forms) |
| 7 Rust nostd quadratic | measured 1 s at 32,768 entries; both linear variants break a device pin; kept (D21) | done by decision |
| 8 TypeScript elementOf, Python import | WeakMap depth bound; module-level `_validate_depth` | done |
| 9 whole-build timing guards | Go, Java, C# guards at 250 levels, with measured sensitivity | done, Go groups bound loose (cubic `foreignNames`, hygiene) |
| 1 debug frames, 5 typed element row | back in `hygiene.md`; D20 asked | split out |

Gap-clear: none. Gap-unclear: none.
