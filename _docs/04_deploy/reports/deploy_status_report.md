# Deploy status

**Date**: 2026-09-23
**Mode**: resume

Kept `_docs/04_deploy/packages.md` and `loop_end_merge: stage`.

## Deploy artifact inventory

| Item | State |
|------|--------|
| `scripts/` | absent |
| `infra/` | absent |
| `.env.example` | token names, empty values |
| `docker-compose.test.yml` | six test images, no published ports |
| `.github/workflows/test.yml` | test on push and pull request |
| `.github/workflows/publish.yml` | publish on a `v*` tag |
| `_docs/02_document/deployment/` | containerization, procedures, environment, observability |

## Host roles

| Role | Host |
|------|------|
| dev | this workstation |
| ci / builder | GitHub Actions |
| registry | npm, NuGet, PyPI, crates.io, Maven Central, vcpkg git |
| deploy | none — a registry publish is the release |

## Gap list

Remote SSH, Woodpecker, and `scripts/deploy.sh` are not gaps to fill. A laptop deploy script would be a second publisher next to `publish.yml`. Health is the golden hex, not an HTTP endpoint.
