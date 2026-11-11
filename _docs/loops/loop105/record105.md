# Autodev loop record - loop 105

loop: 105
branch: dev
plan_artifact: _docs/loops/loop105/plan105.md
tasks_shipped: []
decisions:
  - owner (2026-11-11): "Yes, plan it", then "make v.0.5.0" (version 0.5.0, the recommended defaults); the owner pushed the tag himself because the agent's tag creation and push were denied by the permission classifier twice ("Create Public Surface"); the owner's "Uploading it" and "how to automate that???" led to the `publish-key` workflow
  - agent defaults: tag `v0.5.0` (annotated) on `4e9110a`, the last commit with green `dev` and `main` runs, so the tag run's precheck skipped its own test call; Dart in the tag with the optional `pubdev` target skipped (pub.dev has no `packbin`); the GitHub release from `release_notes_0.5.0.md`; the failed job re-run with `gh run rerun --failed`
measurements:
  - tag run `43041230549` on `4e9110a`: attempt 1 (2026-11-11 14:43) published npm, PyPI, crates.io, NuGet and the vcpkg branch and failed at Maven Central (all four signatures: "Could not find a public key by the key fingerprint"); attempt 2 (15:50, after `publish-key` run `43051265000` put the key on `keys.openpgp.org`) published Maven Central, pushed `go/v0.5.0` at the same commit, passed the Swift consumer check and skipped `pubdev` with the expected warning
  - the signing key in the secret `MAVEN_GPG_PRIVATE_KEY` is `3C51A862BEA87BC1BE7B0AB5AC576082216B95B9` (no passphrase; the same key as the 0.4.0 signatures); this Mac has no GPG secret key and the owner's GitHub account lists none
  - verified from outside: npm, PyPI, crates.io, NuGet and Maven Central (pom and `.asc`) answer for 0.5.0; `go/v0.5.0` and `v0.5.0` both at `4e9110a`; the GitHub release https://github.com/zxsanny/packbin/releases/tag/v0.5.0 is the latest
  - smoke: 9/9 (`smoke105.md`)
review: "none (no application source changed); the new workflow `publish-key.yml` was shellchecked, YAML-parsed, its key and fingerprint logic tested with a throwaway key, and run once for real"
retro: none (the loop 104 retro is current; next due by loop 109)
leftovers:
  - CI: the `embedded-arm` job fails on the workflow commit `61505c9` in `dev` and `main` (two attempts, 25 minutes apart): `Could not resolve 'archive.ubuntu.com'` inside the Docker image build of `cpp/embedded/run.sh host arm`; 19 of 20 jobs pass, the job and its Dockerfile are untouched by that commit, and it passed on `4e9110a` at 13:10; a third attempt of the `dev` run (about 55 minutes after the first) failed the same way in 54 s; the cause is not identified (the Dockerfile `FROM ubuntu:24.04` with `apt-get update` over http has not changed since AZ-3479; `archive.ubuntu.com` resolves from the owner's Mac and through 1.1.1.1; the runner image version could not be read from the logs); it does not touch the release (the tag run's precheck used the green runs of `4e9110a`), but a tag on this `dev` head would need that job green or its own test call to pass
  - owner (before the first tag that contains `dart/` can publish Dart): publish a first version by hand with `dart pub publish`, then enable automated publishing for `zxsanny/packbin` with tag pattern `v{{version}}`; afterwards edit the two README lines that say Dart is installed from the repository (the 0.5.0 run skipped `pubdev` with the warning)
  - automate the signing key for good: `publish-key` is a one-click fix after a failure; to make every tag run re-assert the public key by itself, add the same upload to `publish-sign.sh` (it already imports the key) with its tests (they run without a network), as a task of its own
  - `keyserver.ubuntu.com` did not answer from this Mac or from the GitHub runner (the upload there failed with a warning); Maven Central read `keys.openpgp.org` successfully
  - the autodev rule file `worktree-isolation.md` still says the `dev` push "is the CI trigger" (documents-only pushes start no run); outside this repository
  - not run here: the vcpkg supports and consumer checks (no vcpkg tool); a physical board
  - from loops 98 to 104 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built
  - Jira: no ticket this loop; AZ-4169, AZ-4168, AZ-4153 and AZ-4134 to AZ-4149 In Testing (the release published them; the owner decides when they move to Done)
smoke: PASS (agent run, owner rule 2026-10-12: 9/9 steps passed at 9d93358; checks in smoke105.md)
smoke_artifact: _docs/loops/loop105/smoke105.md
loop_end_merge: main
