# Infrastructure review

**Date**: 2026-09-29

No production Dockerfile. Tests use `docker-compose.test.yml` with no published ports.

| Check | Result |
|-------|--------|
| Secrets in CI | `publish.yml` injects `secrets.*`. `test.yml` does not |
| `.env.example` | token names only, values empty |
| Containers | test images have no `USER` directive and use floating tags |
| Actions checkout | `actions/checkout@v7` in `test.yml` and `publish.yml`, not a commit SHA |
| Network | compose publishes no port |
| TLS | registry calls use https URLs |
| Maven | `publish-registries.sh` writes a detached `.asc` signature when `MAVEN_GPG_PRIVATE_KEY` is set |
