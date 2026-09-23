# Deployment procedures

1. Tests are green on the commit.
2. The golden hex matches in every present language.
3. Push a version tag. GitHub Actions publishes the six registries.

There is no HTTP health endpoint. The check is the position pack `4001000065cd1d00a3e1110100`.

Rollback is unlist or deprecate the published version. Do not force-push the tag.
