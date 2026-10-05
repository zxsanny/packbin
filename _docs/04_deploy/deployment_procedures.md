# Deployment procedures

1. Tests are green on the commit. `publish.yml` calls `test.yml` on the tagged commit first; the `publish` job needs it, so a red test job publishes nothing. A tag runs the tests once, through `publish.yml`.
2. The golden hex matches in every present language.
3. Push a version tag. GitHub Actions builds and checks every artifact first, then uploads to the six registries; a failed build uploads nothing. `PACKBIN_BUILD_ONLY=1` runs the build phase alone with no credential and no network write.

There is no HTTP health endpoint. The check is the position pack `4001000065cd1d00a3e1110100`.

Rollback is unlist or deprecate the published version. Do not force-push the tag.
