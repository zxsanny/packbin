# Autodev loop record - loop 110

loop: 110
branch: dev
plan_artifact: none (a release, no plan file; as loop 105)
tasks_shipped: []
decisions:
  - owner (2026-11-11): "make release v.0.5.1" in the session of loop 109, after the loop closed and while its `main` run was in progress; the owner had asked a moment before for the AZ-4199 review and the `main` fast-forward at loop close
  - agent defaults: version 0.5.1 (as asked); annotated tag `v0.5.1` on `9df1db7`, the close commit of loop 109, once its `main` run was green (20 of 20); notes written from the git log since `v0.5.0`; the GitHub release from the notes body (`gh release create v0.5.1 --verify-tag`)
  - the tag push was allowed this time (v0.5.0: the permission classifier denied the agent's push twice and the owner pushed it)
measurements:
  - tag run `43106289000` (attempt 1, no re-run): precheck found the green `main` run and skipped the test call; `publish` 21:48 to 22:07 UTC, success; the signing key was already served by `keys.openpgp.org` (the AZ-4196 send branch did not run); `pubdev` skipped with its warning; `go/v0.5.1` pushed at 22:04:32 and the proxy answered on the first try; `swift-check` ok
  - verified from outside: npm, PyPI, crates.io, NuGet, Maven Central (pom and `.asc`), the `vcpkg` branch (`7818682`, `version packbin 0.5.1`), `v0.5.1` and `go/v0.5.1` both at `9df1db7`, the GitHub release https://github.com/zxsanny/packbin/releases/tag/v0.5.1 is the latest
  - smoke: 10/10 (`smoke110.md`)
review: "none (no source changed in this loop; the released code is the loop 109 head: AZ-4199 was reviewed in its own batch report, PASS_WITH_WARNINGS, and by the agent's read of its source diff)"
retro: none (next due by loop 113)
leftovers:
  - the send branch of the AZ-4196 key upload has not run for real (the key was already served); `publish-key` stays the manual fallback
  - owner (unchanged): first `dart pub publish`, then automated publishing for `zxsanny/packbin` with tag pattern `v{{version}}`; afterwards edit the two README lines that say Dart is installed from the repository
  - Jira: AZ-4198 and AZ-4199 In Testing; the release published them, the owner decides when they move to Done
  - from loop 109 (unchanged): the AZ-4199 Lows, the `dotnet test csharp` hang without a console logger, the embedded-arm DNS cause (not reproduced; `diagnose-dns` is the tool)
  - from loops 98 to 108 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built; keyserver.ubuntu.com did not answer in loop 105; the autodev rule file `worktree-isolation.md` is outside this repository
smoke: PASS (agent run, owner rule 2026-10-12: 10/10 steps passed; checks in smoke110.md)
smoke_artifact: _docs/loops/loop110/smoke110.md
loop_end_merge: main
