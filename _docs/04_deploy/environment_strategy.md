# Environment strategy

| Environment | What it is | Secrets |
|-------------|------------|---------|
| Development | the workstation | none for the library |
| CI | GitHub Actions | registry tokens, tag job only |
| Registries | the six public registries | the published packages |

There is no application server. `main` in the loop-end channel is a git ref, not a host (owner decision 2026-10-06; there is no `stage` branch). Production is a published package version.
