# Deployment procedures

## Release

1. Tests are green on the commit. The tag run enforces it: `publish.yml` first calls `test.yml` (read-only token, no secrets) on the tagged commit, and the `publish` job needs that call. A failing test job skips `publish`. `test.yml` does not run on its own for a tag, so a tag runs the tests once.
2. The golden hex matches in every language present in the tree (`publish-gate.sh`). Mismatch count is 0.
3. Push a version tag. Actions first builds and checks every artifact (build phase: version, MIT, payload; any failure stops the run before any upload), then uploads the built files (upload phase). `PACKBIN_BUILD_ONLY=1` runs the build phase alone with no credential and no network write. Actions publishes npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin`, and vcpkg `packbin`. The same tag also publishes the C++ sources to PlatformIO, the ESP-IDF component registry and an Arduino branch and tag.

## Health check

There is no HTTP health endpoint. The check is FT-P-01: the position values pack to `4001000065cd1d00a3e1110100`.

## Re-run

A partial publish is finished by re-running the tag's `publish.yml` run in Actions, or by a new run for the same tag ref. Each target whose exact version is already published is skipped with `already published <target> <version>`; the rest is uploaded. A complete earlier run re-runs to exit 0 with no write. Runs for one tag are serialized by a `concurrency` group keyed by the tag ref (no cancel-in-progress). Never upload by hand and never move the tag.

Required: NuGet, npm, PyPI, crates.io, Maven Central, vcpkg. A missing credential fails the run before any write and a failed upload fails the run. Optional: PlatformIO, ESP-IDF, Arduino. A missing credential skips the target with a `::warning::` and a `$GITHUB_STEP_SUMMARY` line; a failed upload with the credential present fails the run.

## Rollback

Unlist the NuGet version and deprecate the npm version. Publish a new patch only after the golden hex matches again. Do not force-push the tag.

## Checklist

- All six packages declare MIT
- The archive contains 0 registry tokens
- Python, Rust, Java, and C++ are in the tag, so PyPI, crates.io, Maven Central, and vcpkg publish with npm and NuGet; none of them is skipped when its credential is missing
- Kotlin is absent, so that registry receives 0 packages
