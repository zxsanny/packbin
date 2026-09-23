# Infrastructure review

**Date**: 2026-09-23

No production Dockerfile. Tests use `docker-compose.test.yml` with no published ports.

| Check | Result |
|-------|--------|
| Secrets in CI | `publish.yml` injects `secrets.*`. `test.yml` does not |
| `.env.example` | token names only, values empty |
| Containers | test images have no `USER` directive and use floating tags |
| Network | compose publishes no port |
| TLS | registry calls use https URLs (`api.nuget.org`, npm, Central, GitHub) |
