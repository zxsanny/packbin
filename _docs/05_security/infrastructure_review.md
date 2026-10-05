# Infrastructure review

**Date**: 2026-10-05

No production Dockerfile. Tests and the embedded job use `docker-compose.test.yml` with no published ports.

| Check | Result |
|-------|--------|
| `cpp/embedded/Dockerfile` | base `ubuntu:24.04` by tag, packages from the distribution, no `curl | sh`, no secrets, no user data. The tag is not a digest (F3) |
| `cpp-embedded-esp` | `espressif/idf:v5.3.2` by tag (F3) |
| `test.yml` `embedded` job | runs `cpp/embedded/run.sh`; no secrets; `actions/checkout@v7` is a moving tag (F1) |
| `test.yml` `scaffold` job | new hostile-case step runs a local script; no network |
| `cpp/embedded/examples.sh` | downloads `arduino-cli` v1.1.1 over HTTPS from the official GitHub release and runs it, with no checksum (F2) |
| Publish scripts for PlatformIO, ESP-IDF, Arduino | skip without their tokens; tokens come from the CI secret store (gate test) |

## Loop 11 addendum

**Date**: 2026-10-05

No workflow, Dockerfile, compose file, publish script or lockfile changed since 9a7847f. F1 (`actions/checkout@v7` in `test.yml` lines 11 and 51, `publish.yml` line 16), F2 (`arduino-cli` download without a checksum, `examples.sh:25-27`) and F3 (base images by tag) are unchanged and open. F3 also applies to the six test images in `docker-compose.test.yml` (`mcr.microsoft.com/dotnet/sdk:10.0`, `node:24`, `python:3.14`, `rust:1.98`, `gcc:16`, `eclipse-temurin:26-jdk`). The audit ran no container and installed nothing.
