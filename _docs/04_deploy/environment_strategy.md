# Environment strategy

| Environment | What it is | Secrets |
|-------------|------------|---------|
| Development | the workstation | none for the library |
| CI | GitHub Actions | registry tokens, tag job only |
| Registries | the six public registries | the published packages |

There is no application server. `stage` in the loop-end channel is a git ref, not a host. Production is a published package version.
