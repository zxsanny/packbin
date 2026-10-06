# Structure — 2026-10-06 loop 14

| Metric | Value | Versus 2026-10-06 loop 13 |
|--------|-------|---------------------------|
| Components | 6 | 0 |
| Cross-component imports | 0 | 0 |
| Cycles | 0 | 0 |
| Contracts | the existing library contracts and the session contract | 0 |
| `shared/` | none | 0 |

New files this loop sit outside the package components: Java `api-check.sh`, `tools/Fetch.java`, `tools/ApiCheck.java`, test `ApiSafeReplacementsTest.java` (inside the Java component); publish scripts `publish-build.sh`, `publish-upload.sh`, `publish-query.sh`, `publish-published.py`, `publish-check.py`, `publish-sign.sh` and tests `publish-phases.test.sh`, `publish-rerun.test.sh` in `.github/workflows/` (the CI/publish component). No package imports another package.
