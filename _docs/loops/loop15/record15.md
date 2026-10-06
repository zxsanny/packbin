# Autodev loop record — loop 15

loop: 15
branch:
worktree: none (worked on dev, same as loops 11 to 14)
plan_artifact: _docs/loops/loop15/plan15.md
tasks_shipped: [AZ-2214_ci_pin_credentialed_job, AZ-2215_build_containers_read_only, AZ-2216_csharp_round_limits, AZ-2217_typescript_round_limits, AZ-2218_java_round_limits, AZ-2219_rust_round_limits, AZ-2220_round_limits_hostile_and_docs]
leftovers:
  - "Security audit (step 14, PASS_WITH_WARNINGS, 0 Critical, 0 High, 2 Medium, 7 Low; `_docs/05_security/security_report.md`). F10 Medium, REDUCED: rounds are capped (defaults 65,535 rounds and 4,194,304 slots per call, settable on the scheme) but the default ceiling is 130 to 430 MB per call and `bits` / `packed` counts stay linear in the packet (36 to 257 times its size); the README now says so. F12 Medium, REDUCED: actions pinned by commit, six pip tools and npm pinned, but about 60 transitive wheels float unhashed, the Maven GPG key is visible to host pip in the build phase, `PYPI_TOKEN` is passed beside OIDC, checkout credentials persist. F13 Low (was Medium), REDUCED: repo read-only in the build and gate containers, symlinks refused in container-built trees; no digest between check and upload (assessment Q2, accepted). F17 Low (new to the report, pre-existing, README documents it): typed C# `Unpack` throws `InvalidCastException` on a packet that holds a round. F14 to F16, F2, F3 carried. No tickets: the owner decides keep, fix or accept"
  - "Assessment round 1 (`assessment15.md`) CLARIFY, answered by the owner on 2026-10-06: Q1 A (slot counting differs slightly per package; judged Low: no attacker gain, memory bounded by the rounds cap times the body cost, README states it), Q2 A (no digest check between the build check and the upload)"
  - "Linux-only parts not proven locally; the first CI run on the Ubuntu runner decides: Compose 2.38.2 merging `docker-compose.publish.yml`, the `/out` bind mount and file ownership (AZ-2215), the pinned `actions/checkout`, `actions/setup-node` and `NuGet/login` commits and the pinned pip tools on Python 3.12.3 (AZ-2214), the Linux ownership assertion. Registry-side, only a real tag proves: Central `published` response shape, the crates.io token lifetime (assessment loop 14 U1, U3)"
  - "Release: v0.2.2 (plan13 `## Release`) is still not created. After CI is green on the final commit the agent shows the exact commit and asks for one go; the Rust three-argument `times` removal is source-breaking (0.3.0 was offered); the new round limits refuse packets above 65,535 rounds until a scheme raises them (the README has an upgrade note)"
  - "Follow-ups noted, not ticketed: `docker-compose.publish.yml` and its config test list the six services by hand (derive them from the base file); a `tsc --noEmit --strict` job in `test.yml` (open since loop 11); the C# element case of the round limits when AZ-2119 lands; `dotnet format` whitespace errors in `csharp/Walker.Scalars.cs` and `csharp/tests/LayoutTests.cs`; `Nfr_RoundTripsWithinOneSecond` fails at about 1.1 s above load average 30; AZ-2194 will conflict on the `cases.test.sh` count (19 now)"
  - "Follow-up hopper under epic AZ-2069 (unclaimed, in todo/), unchanged: AZ-2180 to AZ-2194, AZ-2197, AZ-2092 and the rest of AZ-2093 to AZ-2105 and AZ-2112 to AZ-2121 (AZ-2214 to AZ-2220 are done); AZ-2068 stays an optional stretch; AZ-2101 still names the removed `PACKBIN_MAVEN_BUNDLE_ONLY`"
  - "Open from earlier loops: the audit's fuzz and amplification harness still lives in a scratchpad (`_docs/AGENT_GOTCHAS.md`); error kind and label of the interim error (C15); C++ and Python have no round limit by design (fixed arrays with `Error::TooMany`; Python keeps only read values)"
  - "Environment: this Mac has no `gpg` (the Java dry run is covered by the gate tests' shim) and the Pico example needs a linux/amd64 container (recipes in `_docs/AGENT_GOTCHAS.md`); loop-end channel is `main` since 2026-10-06 (`ci_cd_pipeline.md`), polling is `enabled: yes` (90 s, GitHub API)"
smoke: PASS
smoke_artifact: _docs/loops/loop15/smoke15.md
assessment_artifact: _docs/loops/loop15/assessment15.md
suite: PASS (Pico run under the CI toolchain)
suite_report: _docs/03_implementation/test_run_loop15_report.md
merged_local: true
conflicts_resolved: ""
loop_end_merge: main (pushed to main only after dev CI is green)
