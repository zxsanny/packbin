# Autodev loop record — loop 14

loop: 14
branch:
worktree: none (worked on dev, same as loops 11 to 13)
plan_artifact: _docs/loops/loop14/plan14.md
tasks_shipped: [AZ-2094_java_release_17, AZ-2095_publish_after_tests, AZ-2096_publish_build_before_upload, AZ-2097_publish_rerun_and_registry_policy]
leftovers:
  - "Security audit (step 14, PASS_WITH_WARNINGS, 0 Critical, 0 High, 3 Medium, 7 Low; `_docs/05_security/security_report.md`). F10 Medium (carried): unpack of a `repeat` / `times` round has no budget. F12 Medium (new): unpinned code runs in the credentialed publish job (pip tools twine, platformio, idf-component-manager; `npm@11`; `NuGet/login@v1`). F13 Medium (new): the build containers mount the whole repo read-write as root, so what is checked is not what the host later runs and uploads. Lows: F11, F1 to F3 carried; F14 any writer's `v*` tag publishes, F15 tag name is the version unvalidated, F16 tokens on argv. No tickets yet: the owner decides keep, fix or accept (retro action 1 proposes pinning the credentialed job and a read-only mount of `.github/workflows` for the build step)"
  - "Feature assessment round 1 (CLARIFY, then accepted with the recommended option A on the owner's `continue`; `assessment14.md`): U1 the crates.io and NuGet tokens are minted before a now longer build phase (a partial release is possible once; a re-run finishes it); U2 the PlatformIO existence check sends the token to look up the owner; U3 Central's `publisher/published` response shape and duplicate-rejection text were never called with a token and fail closed. All three are re-checked on the first real tag"
  - "Release: v0.2.2 (plan13 `## Release`, plan14) is still not created. It needs one explicit confirmation with the exact commit, a green `test.yml` on it, and the owner's answer on `origin/main`. The first tag is also the first proof of GitHub's `workflow_call`, `needs` and branch-only `push` behavior, the Maven Central answer, the crates.io token lifetime and the cold build time; the Rust three-argument `times` removal is source-breaking (0.3.0 was offered)"
  - "Follow-up hopper under epic AZ-2069 (unclaimed, in todo/), unchanged from loop 13: AZ-2180 to AZ-2194, AZ-2197, AZ-2092 and the rest of AZ-2093 to AZ-2105 and AZ-2112 to AZ-2121 (AZ-2094 to AZ-2097 are done); AZ-2068 stays an optional stretch. AZ-2101 still names the removed `PACKBIN_MAVEN_BUNDLE_ONLY` in its risk text"
  - "Not in any ticket: the ESP-IDF archive holds the whole `cpp/` tree, not only the manifest's include list; `python/pyproject.toml` `project.license` as a TOML table is deprecated (breaks after 2027-02-18); the PyPI and npm OIDC upload branches have no test; a re-run rebuilds every target before the existence checks; `.github/workflows/language-pair.sh` compiles the Java handoff driver without `--release`"
  - "Open from earlier loops: no `tsc --noEmit --strict` job in `test.yml` (the strict flags are now in `_docs/AGENT_GOTCHAS.md`); the audit's fuzz and amplification harness still lives in a scratchpad (`_docs/AGENT_GOTCHAS.md`); error kind and label of the interim error (C15)"
  - "Loop-end channel: `loop_end_merge: stage` is recorded in `ci_cd_pipeline.md`, but `origin` has no `stage` branch (branches: `arduino`, `dev`, `main`). The stage fast-forward was not run: creating a new remote branch is the owner's call (see the close message)"
  - "Environment: Pico and ESP toolchains live in the gitignored `.cache/embedded/` (about 8.5 GB: the arm64 PlatformIO packages and a separate x86_64 set under `.cache/embedded/amd64`); the Pico example builds on this Mac with both the arm64 (GCC 9.3.1) and the CI toolchain (GCC 9.2.1, linux/amd64 container) outside the stage script. This Mac has no `gpg`: a build-only run with Java needs it on the host"
smoke: PASS
smoke_artifact: _docs/loops/loop14/smoke14.md
assessment_artifact: _docs/loops/loop14/assessment14.md
suite: PASS (Pico run outside the stage script, both toolchains)
suite_report: _docs/03_implementation/test_run_loop14_report.md
merged_local: true
conflicts_resolved: ""
loop_end_merge: stage (not executed: no origin/stage branch)
