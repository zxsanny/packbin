# Deployment procedures

1. Tests are green on the commit. `publish.yml` calls `test.yml` on the tagged commit first; the `publish` job needs it, so a red test job publishes nothing. A tag runs the tests once, through `publish.yml`.
2. The golden hex matches in every present language.
3. Push a version tag. GitHub Actions builds and checks every artifact first, then uploads to the six required registries (and the three optional embedded ones whose credential is set); a failed build uploads nothing, and a missing required credential stops the run before any build. `PACKBIN_BUILD_ONLY=1` runs the build phase alone with no credential and no network write.

There is no HTTP health endpoint. The check is the position pack `4001000065cd1d00a3e1110100`.

Re-run: if an upload failed, re-run the tag's `publish.yml` run in Actions (or start a new run for the same tag ref). Registries that already hold the version are skipped with `already published <target> <version>` and the rest is uploaded. Do not publish by hand and do not move the tag. Two runs for one tag queue, they do not overlap.

Required registries: NuGet, npm, PyPI, crates.io, Maven Central, vcpkg. A missing credential or a failed upload fails the run. Optional: PlatformIO, ESP-IDF, Arduino. A missing credential skips the target with a `::warning::` and a job-summary line; a failed upload still fails the run. Details: `_docs/04_deploy/packages.md`.

Rollback is unlist or deprecate the published version. Do not force-push the tag.
