# Infrastructure review

**Date**: 2026-10-06
**Scope**: loop 16 (`git diff 9db438e..HEAD`, HEAD 5c95950): `.github/workflows/test.yml` (new `ring` job, two new steps in `scaffold`), `ring-cxx.sh`, `ring-toolchains.sh`, `language-pair.sh`, `publish-inside.sh` (npm build), `publish-embedded.sh` (vcpkg port), `publish-check.py` (committed hunks only), `publish-position.sh`, `cpp/embedded/{lib,arm,esp,examples,run}.sh`, `cpp/embedded/lib.test.sh`, the new gate tests. `publish.yml`, `docker-compose.test.yml`, `docker-compose.publish.yml`, `publish-{lib,registries,upload,sign,query,build,gate}.sh`, `crates-token.sh`, `tool-pin*` are unchanged since loop 15 (empty `git diff`), so their loop 15 results and line numbers stand. No production Dockerfile; no deployed service. Not run: Docker (not allowed in this audit), so the compose and wrapper behavior below is from reading, not from a container run.

## GitHub Actions permissions, triggers and pins

| Check | Evidence | Result |
|-------|----------|--------|
| Workflow default permissions | `test.yml:9-10`, `publish.yml:8-9` | `contents: read` |
| Who holds write or id-token | `publish.yml:23-25` | only job `publish`; the `test` call (`publish.yml:16-19`) and so the new `ring` job hold `contents: read`; no `secrets: inherit` |
| Triggers | `test.yml:3-7`, `publish.yml:3-6` | `test` on push to any branch, pull request, `workflow_call`; `publish` on `v*` tags. The `ring` job therefore runs repository code on every push and pull request with a read-only token and no secret; fork pull requests get no secret either |
| Action pinning (F1) | `test.yml:17,63,92,93,96,99,102`, `publish.yml:29,32,37` | all 10 non-local `uses:` are 40-hex commits with a tag comment; each equals its tag by `git ls-remote --tags` (see `dependency_scan.md`) |
| `ring` job inputs | `test.yml:73-122` | `timeout-minutes: 30`; versions in job `env` (`RING_*`); `setup-dotnet`, `setup-node`, `setup-python`, `setup-java` pinned; `rustup toolchain install "$RING_RUST" --profile minimal --no-self-update` (exact version, official channel, no checksum); `docker pull "gcc:$RING_GCC"` (tag); `npm ci --prefix typescript` (lockfile integrity; neither locked package has an install script, but `--ignore-scripts` is not passed, unlike `publish-inside.sh:66`); `dotnet build` of the driver project and `cargo build` of `handoff-rust` (path dependencies only) |
| Checkout credential | `test.yml:92`, `publish.yml:29` | `persist-credentials` not set to `false` (F12 item, unchanged); in the `ring` job the token is `contents: read` |
| Secrets in new steps | `test.yml`, `ring-toolchains.sh` | none passed; the job prints toolchain versions only |

## The `ring` compiler wrapper (F20, known item Q9)

`ring-cxx.sh:15-25` runs `docker run --rm -i --user "$(id -u):$(id -g)" -v /tmp:/tmp -v "<repo>:<repo>" -w "$PWD" gcc:16 g++ "$@" -static`.

| Aspect | Today | Effect | Needed by the ring? |
|--------|-------|--------|---------------------|
| User | runner uid and gid, not root | files it writes belong to the runner; cannot touch root-owned files | yes, kept |
| Repository mount | read-write at its host path (`:21`) | a tampered image, or a compiler plugin, could rewrite any file the host runs next, `language-pair.sh` itself included (bash reads a script while it runs), the other drivers, or a source that `dotnet`, `node`, `java` and `cargo` then execute on the runner: a false green ring, with the job's read-only token. No secret is in reach | no: g++ only reads the sources and writes `-o <path under /tmp>`; `:ro` works |
| Host `/tmp` | mounted read-write at `/tmp` (`:15`) | the container can plant `/tmp/packbin-handoff-java/Handoff.class` and `HandoffElements.class` (reused by `language-pair.sh:67-68` when newer than the sources, then run with `java -cp`) or any file the ring later reads | the ring writes only `$PACKBIN_CPP_HANDOFF`, `$PACKBIN_CPP_BIN`, which default under `/tmp` but are overridable (`language-pair.sh:50`, `publish-position.sh:60`); a per-run `mktemp -d` bound at its own path is enough |
| Network | default bridge | outbound access, including the runner's metadata endpoint | no: the compile needs none |
| Capabilities, `no-new-privileges`, pids and memory limits | defaults | a larger escape surface than needed | no |
| Image | `gcc:16` by tag (F3) | a moved tag changes the compiler of the ring | pin by digest |
| What it cannot reach | the checkout credential file (it lives under `RUNNER_TEMP`, not `/tmp`, and is not mounted; the repository's `.git/config` only names it), the other runners' files | | |

Remediation: `--network none --cap-drop ALL --security-opt no-new-privileges --pids-limit 256`, `-v "$dir:$dir:ro"` for the repository and the working directory, a private output directory (`mktemp -d`, exported through `PACKBIN_CPP_HANDOFF` and `PACKBIN_CPP_BIN`, mounted read-write at its own path) in place of `/tmp:/tmp`, and the image by digest. Q9 waits for the first green `ring` run; none of this changes a ring result.

## Publish: build, check, upload (loop 15 design, loop 16 changes)

| Check | Result |
|-------|--------|
| Build phase holds no registry credential | unchanged: `publish-registries.sh:111-118` (loop 15). The new `build_vcpkg` and the npm build run in that phase: `build_vcpkg` clones the `vcpkg` branch of this repository anonymously (`publish-lib.sh:124-130`, no token in the URL), commits locally and leaves the push to `publish-upload.sh` |
| npm build container | `publish-inside.sh:60-68` in the `node:24` image with the repository mounted read-only (`docker-compose.publish.yml:9-12`): copy, delete `node_modules` and `dist`, `npm version` (semver only), `npm ci --ignore-scripts`, `npm run build`, `npm pack`. Network is needed for `npm ci` (lockfile integrity protects the packages). The tarball is checked on the host by `publish-check.py:100-122` before upload; a scratch pack of the HEAD tree passed (26 files, no `src/`) |
| vcpkg staging | `publish-embedded.sh:55-87` on the host from the checkout; `rm -rf` is scoped to `$reg/ports/packbin`; the push stays in `publish-upload.sh` (unchanged) with `GITHUB_TOKEN` (`contents: write`) |
| Tag-time guard | committed hunks of `publish-check.py` only. `refuse_symlinks` (`:257-276`) refuses a symlink in the five container trees (probed). npm assertions `:93-122`, vcpkg assertions `:193-217`. Gaps: F23, F13 residue |
| Container-written trees | unchanged otherwise: root in the container, default network and capabilities, digest between check and upload not recorded, Rust uploads `stage/` rather than the checked `.crate` (F13) |
| Embedded harness | `lib.sh` `run_target` now fails a target on any non-zero command and counts it (`lib.sh:62-104`); `lib.test.sh` runs it against fake targets in `mktemp -d` trees with a `trap` cleanup. `examples.sh:29-31` still downloads `arduino-cli` 1.1.1 with no checksum and `:71-72` installs the ESP32 core without a version (F2); these run in the `embedded` job, which has no secret |
| `ring-toolchains.sh` | reads version strings only; `printf ... \| "$CXX" -E -P -x c++ -` feeds a fixed program to the wrapper's stdin |

## Secrets and credential flow

| Check | Evidence | Result |
|-------|----------|--------|
| No secret reaches a container | `publish-registries.sh:111-118`, `publish_container` (`publish-lib.sh:102-107`) unchanged; `ring-cxx.sh` passes no `-e` | verified by reading: containers get only `SRC_ROOT`, `PACKBIN_VERSION`, `PACKBIN_OUT`, `PACKBIN_HOST_UID/GID` and the compose constants; the `ring` wrapper passes none |
| New test scripts | `publish-vcpkg.test.sh:92` runs `env -u GITHUB_TOKEN -u PLATFORMIO_AUTH_TOKEN -u IDF_COMPONENT_API_TOKEN`, stages into a local bare repository (`git init --bare` in `mktemp -d`); `publish-npm.test.sh`, `publish-position.test.sh`, `ring-wiring.test.sh`, `lib.test.sh` use `mktemp -d` and cleanup traps, no registry URL, no token, no docker | no registry write path and no credential added |
| Secrets in the diff | grep of the added lines | none |
| Token on argv | see `static_analysis.md` | unchanged (F16) |
| Local note | `.env` is gitignored and untracked; every test container mounts the repository root, so a developer-machine `.env` is readable by test code; CI has none, a laptop publish is forbidden (`restrictions.md`) | unchanged |

## Temp directories

All new scripts that create state use `mktemp -d` with a `trap ... EXIT` (`publish-position.sh:17-18`, `publish-inside.sh:20,37`, `publish-embedded.sh:18-19`, `lib.test.sh:48-49`, `ring-wiring.test.sh:13-14`, `publish-position.test.sh:19-20`). Two kinds of fixed names remain (F24): `/tmp/packbin-handoff`, `/tmp/packbin-handoff-java`, `/tmp/packbin-position`, `/tmp/packbin-position-java`, `/tmp/packbin-position-rust` as defaults of the cross-language ring and the position gate, one of which is executed when it already exists. Harmless on a single-user runner (the CI case); on a shared developer or self-hosted machine another user can plant a class file or a binary there. `publish-vcpkg.test.sh:471` sets an `EXIT` trap inside a function, which replaces an earlier trap of the sourcing shell: hygiene only.

## Image pinning

Tags only: `mcr.microsoft.com/dotnet/sdk:10.0`, `node:24`, `python:3.14`, `rust:1.98`, `gcc:16` (also the ring compiler), `eclipse-temurin:26-jdk`, `espressif/idf:v5.3.2`, `ubuntu:24.04` (F3, unchanged).

## Findings carried and new

Carried: F1 fixed, F2 (lines moved to `examples.sh:29-31,71-72`), F3 (extended by `gcc:16` in the `ring` job), F12 (unchanged), F13 (symlink route closed by commit 049d27c, residue as listed), F14, F15 (the vcpkg heredoc added), F16, F17. New: F18 (library), F19 (library), F20 (ring wrapper), F21 (library), F22 (library), F23 (tag-time guard), F24 (fixed `/tmp` names). Details in `security_report.md`.

## Earlier loops (condensed)

Loop 15: read-only build containers, tool pins, action pins, credential flow, symlink behavior of `cargo package`. Loop 14: `timeout-minutes` on every job; build phase credential stripping; F12 to F16. Loop 13: toolchain cache moved to the gitignored `.cache/embedded/`; gate test generates its GPG key into a `mktemp` keyring. Loop 11: F3 extended to the six test images. Loop 10: `cpp/embedded/Dockerfile` base by tag, packages from the distribution, no secrets; `examples.sh` downloads `arduino-cli` 1.1.1 with no checksum (F2).

## Loop 17 addendum (2026-10-07)

No infrastructure file changed in the loop 17 batches. Since loop 16 the owner's multi-target commit (`68ca4f8`) changed three CI files, all read: `run-suite.sh` runs the C# suite a second time with `-p:PackbinTarget=netstandard2.0` (same container, same mounts); `publish-check.py` requires both `lib/netstandard2.0/Packbin.dll` and `lib/net10.0/Packbin.dll` in the `.nupkg` (a stricter artifact check, no new input); `publish-phases.test.sh` follows. The total test run of loop 17 ran `publish-gate.test.sh` and the C# container suite against them. Findings F12, F13, F14, F15, F16, F20, F23, F24 are unchanged.
