# CI/CD pipeline

## Loop-end channel (ordinary product loops)

loop_end_merge: stage

## Pipeline

GitHub Actions. `test.yml` runs on every branch push (`branches: ["**"]`, not tags), every pull request, and as a called workflow (`workflow_call`); `scaffold` has `timeout-minutes: 60`, `embedded` 90. `publish.yml` runs on a `v*` tag: its `test` job calls `test.yml` (read-only token, no secrets), and the `publish` job `needs` it, so a failing test job skips the publish. `publish` alone has `contents: write` and `id-token: write` (`timeout-minutes: 60`), and a `concurrency` group `publish-${{ github.ref }}` (no cancel-in-progress) serializes runs of one tag.

The publish job builds and checks every artifact first (`publish-build.sh`; `PACKBIN_BUILD_ONLY=1` runs this phase alone, with no credential and no registry write), then uploads what is not yet published (`publish-upload.sh`). Required targets (NuGet, npm, PyPI, crates.io, Maven Central, vcpkg) need their credential or the run fails before any write; optional targets (PlatformIO, ESP-IDF, Arduino) are skipped with a warning when it is missing. Re-running the tag finishes a partial publish. See `packages.md`.

`publish-gate.test.sh` (run by the `scaffold` job) checks this structure by parsing the workflow YAML with Ruby `yaml`.

## Post-deploy polling (agent configuration)

enabled: no

There is no deploy host to probe. The test and publish results are the GitHub Actions checks.
