# Structure — 2026-10-06 loop 15

| Metric | Value | Versus 2026-10-06 loop 14 |
|--------|-------|---------------------------|
| Components | 6 | 0 |
| Cross-component imports | 0 | 0 |
| Cycles | 0 | 0 |
| Contracts | the existing library contracts and the session contract | 0 |
| `shared/` | none | 0 |

New files this loop sit inside existing components or in the CI/publish component: `csharp/tests/RoundLimitTests.cs`, `typescript/tests/round-limits.test.ts`, `java/src/main/java/packbin/Cursor.java` and `RoundLimitsTest.java`, `rust/tests/round_limits_tests.rs` and the `slots` field in `FieldKind`; `docker-compose.publish.yml`, `.github/workflows/{tool-pins.txt, tool-pin.sh, publish-pins.test.sh, publish-readonly.test.sh}`. No package imports another package.
