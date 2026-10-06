# Infrastructure review

**Date**: 2026-10-06
**Scope**: loop 14: `.github/workflows/publish.yml`, `test.yml`, `publish-*.sh|py`, `crates-token.sh`, `docker-compose.test.yml`, `java/api-check.sh`. No production Dockerfile; no deployed service.

## GitHub Actions permissions and triggers

| Check | Evidence | Result |
|-------|----------|--------|
| Workflow default permissions | `publish.yml:8-9`, `test.yml:9-10` | `contents: read` |
| Who holds write / id-token | `publish.yml:23-25` | only job `publish`: `contents: write`, `id-token: write`. Job `test` (reusable call) sets `contents: read` (`:17-19`); its jobs `scaffold` and `embedded` inherit read only |
| `secrets: inherit` | grep over `.github/` | none. The called workflow receives no secret; `test.yml` references none |
| Secrets in the publish job | `publish.yml:46-56` | passed by `env:` to one step: `PYPI_TOKEN`, `MAVEN_CENTRAL_TOKEN`, `MAVEN_GPG_PRIVATE_KEY`, `PLATFORMIO_AUTH_TOKEN`, `IDF_COMPONENT_API_TOKEN`, `GITHUB_TOKEN`, plus step outputs for NuGet and crates.io. Not job-level env, so the gate step and tool-install steps do not receive them; `ACTIONS_ID_TOKEN_REQUEST_*` are present in every step of the job |
| Triggers | `test.yml:3-7`, `publish.yml:3-6` | `test` on branch push (`branches: ["**"]`), PRs and `workflow_call`; `publish` on tags `v*` only. Fork PRs run `test` with a read-only token and no secret. `publish-gate.test.sh:316-331` asserts that `test.yml` push has no tags filter |
| `github.*` in `run:` | grep | none; `ref_name` only via `env:` (`publish.yml:48`) |
| Action pinning | `publish.yml:29,32,37`, `test.yml:17,58` | `actions/checkout@v7` (3 uses), `actions/setup-node@v7`, `NuGet/login@v1`: moving tags (F1; F12 for the credentialed ones) |
| `actions/checkout` credential | `publish.yml:29` | `persist-credentials` not set to `false`; the job token (`contents: write`) is stored by checkout for the rest of the job. How v7 stores it is not verifiable here (earlier majors keep it in a file under `RUNNER_TEMP`, outside the container mounts). Host-side code (pip packages) could read it (F12) |
| Timeouts | `publish.yml:27`, `test.yml:15,56` | set on all three jobs (new in loop 14) |
| Concurrency | `publish.yml:11-13` | group per ref, no cancel |

## Secrets and credential flow

| Check | Evidence | Result |
|-------|----------|--------|
| Build phase holds no registry credential | `publish-registries.sh:106-113` | subshell unsets every variable in `PACKBIN_CREDENTIALS` (11) except `MAVEN_GPG_PRIVATE_KEY`, then `exec`s `publish-build.sh`. Containers receive only `SRC_ROOT`, `PACKBIN_VERSION`, `PACKBIN_OUT` (`publish-build.sh:44-49`) plus `SRC_ROOT`, `FIXTURE`, `TEST_RESULTS` from compose (`docker-compose.test.yml:7-10` etc.); no `env_file`, no pass-through names, no `${VAR}` interpolation, so the host environment does not enter a container. No docker socket mount. **Environment: verified. Filesystem: not isolated (F13)** |
| GPG key only in a real publish | `publish-sign.sh:21-29` | key from env; build-only generates a throwaway key; with neither it refuses. The throwaway key cannot be uploaded (dry-run marker). The real key is visible to host-side `pip install` in the build phase (`publish-embedded.sh:128,134`), F12 |
| GITHUB_TOKEN for git push | `publish-lib.sh:140-162` | askpass helper reads it from env; not in argv, not in a file |
| Token on argv | see static_analysis.md | six sites (F16) |

## Containers

| Check | Result |
|-------|--------|
| Image pinning | tags only: `mcr.microsoft.com/dotnet/sdk:10.0`, `node:24`, `python:3.14`, `rust:1.98`, `gcc:16`, `eclipse-temurin:26-jdk`, `espressif/idf:v5.3.2`, `ubuntu:24.04` (F3, unchanged) |
| User | every service runs as the image default (root) with `./:/src` read-write (`docker-compose.test.yml:12,25,38,51,64,77,91,102`); no `read_only`, no `cap_drop`, default bridge network (can reach the internet). Needed for the build and unavoidable for the unpinned `setuptools` fetch, but see F13 for what the mount exposes in the publish job |
| Published ports | none |
| `chmod -R a+rwX "$artifacts/$lang"` | `publish-build.sh:50`: makes root-owned container output removable and writable by the runner user, and by every other user on the host. On a GitHub-hosted runner there is one user; on a self-hosted multi-user runner any local user can replace a checked artifact before upload (part of F13) |

## Network and registry traffic

All registry calls are HTTPS with default TLS verification, `--max-time 20 --connect-timeout 10` on queries, no `-L` (`publish-query.sh:26-27`). Hosts: `api.nuget.org`, `registry.npmjs.org`, `pypi.org`, `crates.io`, `central.sonatype.com`, `api.registry.platformio.org`, `components.espressif.com`, `repo1.maven.org` (test time, hash pinned), `github.com` (git). The PlatformIO owner lookup is `pio account show`, which sends `PLATFORMIO_AUTH_TOKEN` to PlatformIO's API through the vendor client; the later registry GET carries no token. Maven's `published` GET carries the Central token (`publish-query.sh:113`), to `central.sonatype.com` only.

## Findings carried and new

F1 (actions on moving tags), F2 (`examples.sh:25-27` unchanged), F3 (images by tag) carried. New: F12, F13 (Medium), F14, F15, F16 (Low). Details in `security_report.md`.

## Earlier loops (condensed)

Loop 10: `cpp/embedded/Dockerfile` base by tag, packages from the distribution, no secrets; `examples.sh` downloads `arduino-cli` 1.1.1 with no checksum (F2). Loop 11: no workflow, Dockerfile, compose or script change; F3 extended to the six test images. Loop 13: toolchain cache moved to the gitignored `.cache/embedded/`; the gate test generates its GPG key into a `mktemp` keyring; no workflow gained a secret or a privilege.
