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
