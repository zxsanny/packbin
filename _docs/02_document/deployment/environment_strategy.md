# Environment strategy

| Environment | What it is | Secrets |
|-------------|------------|---------|
| Development | the workstation | none for the library |
| CI | GitHub Actions | registry tokens, used only by the tag job |
| Registries | npmjs.org and nuget.org | the published packages |

There is no application server to stage. The git branch `stage` is the loop-end merge target recorded in `_docs/04_deploy/ci_cd_pipeline.md`. It is not a host.

Production for this library is the public package version. Rolling it forward is a new version tag.
