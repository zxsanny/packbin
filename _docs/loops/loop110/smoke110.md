# Loop 110 smoke - release v0.5.1 (checks run by the agent)

LOCAL_URL: none (a release: no UI, no local deploy)
Branch: dev

One bash script, `_docs/loops/loop110/smoke110.sh` (run from the repository root). Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it and passes the gate when every step passes. Checks: npm, PyPI, crates.io, NuGet and Maven Central (pom and signature) serve 0.5.1; `v0.5.1` and `go/v0.5.1` are both at `9df1db7`; the `vcpkg` branch carries `version packbin 0.5.1`; the GitHub release `v0.5.1` is the latest; the tag run 43106289000 and the `main` run 43105138008 of the tagged commit are success; the tag points at the tested commit.

## Result

10/10 steps passed (agent run, 2026-11-11 after the tag run). The Go proxy was not asked by hand (the tag run's own check answered on the first try).
