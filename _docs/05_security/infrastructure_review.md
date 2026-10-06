# Infrastructure review

**Date**: 2026-10-06
**Scope**: loop 15: `.github/workflows/publish.yml`, `test.yml`, `tool-pins.txt`, `tool-pin.sh`, `publish-{lib,build,gate,inside,position,upload,sign,check}`, `docker-compose.test.yml`, `docker-compose.publish.yml`, `cpp/embedded/{examples.sh,Dockerfile}`, the two new test scripts. No production Dockerfile; no deployed service.

## GitHub Actions permissions, triggers and pins

| Check | Evidence | Result |
|-------|----------|--------|
| Workflow default permissions | `publish.yml:8-9`, `test.yml:9-10` | `contents: read` |
| Who holds write / id-token | `publish.yml:23-25` | only job `publish`: `contents: write`, `id-token: write`; job `test` (reusable call) `contents: read` (`:16-19`) |
| `secrets: inherit` | grep over `.github/` | none (the only hit is a negative test in `publish-gate.test.sh:399`) |
| Secrets in the publish job | `publish.yml:44-57` | passed by `env:` to one step: `PYPI_TOKEN`, `MAVEN_CENTRAL_TOKEN`, `MAVEN_GPG_PRIVATE_KEY`, `PLATFORMIO_AUTH_TOKEN`, `IDF_COMPONENT_API_TOKEN`, `GITHUB_TOKEN`, plus step outputs for NuGet and crates.io. Not job-level env. `ACTIONS_ID_TOKEN_REQUEST_*` are present in every step |
| Triggers | `test.yml:3-7`, `publish.yml:3-6` | unchanged: `test` on push, PR and `workflow_call`; `publish` on tags `v*` |
| Action pinning (F1) | `publish.yml:29,32,37`, `test.yml:17,59` | **all five `uses:` are 40-hex commits with a `# <tag>` comment**. `git ls-remote --tags`: `actions/checkout` `v7.0.1` and `v7` = `3d3c42e5...90b1`; `actions/setup-node` `v7.0.0` and `v7` = `82076278...0fe5020`; `NuGet/login` `v1.2.0` = `8d196754...1028841`, and the annotated `v1` peels (`v1^{}`) to the same commit. The two third-party-code actions run a bundled `dist/index.js` (`node24`), so the commit fixes what runs. `publish.yml:19` is the one local `uses:`. `publish-pins.test.sh` fails on any non-local reference that is not owner/repo plus 40 lowercase hex plus a tag comment |
| Tool pins | `tool-pins.txt`, `publish.yml:36` | `npm install -g "npm@11.21.0"` via `tool-pin.sh`; npm's own dependencies are bundled in its tarball, so no transitive float; pip tools in `ensure_tool` and `run-suite.sh`, `examples.sh:15-16`, `publish-inside.sh:72-74`: exact version plus `--only-binary=:all:`. Every `pip install`, `npm install` and `npm ci` in `.github/`, `cpp/embedded/` and the compose files was grepped: the only installs that are not exact are the transitive pip dependencies (F12), `npm ci` (locked by `package-lock.json`, `publish-position.sh:46`, `run-suite.sh:30`), `apt-get install` in `cpp/embedded/Dockerfile:7-8`, and `arduino-cli core install esp32:esp32` (`examples.sh:66`). No `curl | sh`, no `cargo install`, no `dotnet tool` anywhere |
| `PIP_CONSTRAINT` | `publish-inside.sh:74` | holds `setuptools`: probe with a copy of the pins file set to `setuptools==83.0.0` made `python -m build` install `setuptools-83.0.0` (pip log); the committed pin is 84.0.0, also the latest. The `npm==` line in the same file is ignored by pip (the build ran with it present). The constraint is a version, not a hash |
| `actions/checkout` credential | `publish.yml:29` | `persist-credentials` not set to `false`. v7.0.1 writes the token into a separate file under `RUNNER_TEMP` and adds `includeIf.gitdir:<repo>/.git.path = <that file>` to `.git/config` (`git-auth-helper.ts:327-375` at the pinned commit). Not in the repo, so not in a container's writable mount; a container can read the file's path from `/src/.git/config`; host processes can read the file. `GITHUB_TOKEN` is also passed to the publish step by `env:` (needed for the vcpkg and Arduino pushes), so `persist-credentials: false` mainly shortens exposure in the other steps |
| Timeouts, concurrency | `publish.yml:11-13,27`, `test.yml:15,56` | unchanged |

## Secrets and credential flow

| Check | Evidence | Result |
|-------|----------|--------|
| Build phase holds no registry credential | `publish-registries.sh:111-118` | the subshell unsets every variable of `PACKBIN_CREDENTIALS` (11) except `MAVEN_GPG_PRIVATE_KEY`, then `exec`s `publish-build.sh`. Containers receive only what `publish_container` and compose give them: `SRC_ROOT`, `PACKBIN_VERSION`, `PACKBIN_OUT`, `PACKBIN_HOST_UID/GID`, `FIXTURE`, `TEST_RESULTS`. `docker compose config` on the merged files: six services, `environment` keys `FIXTURE`, `SRC_ROOT`, `TEST_RESULTS` only; no `env_file`, no `${...}` interpolation in either file. **(d) verified: no secret reaches a container** |
| Key visible to host-side pip | `publish-embedded.sh:128,134` | the Maven key is in the environment when `ensure_tool pio` and `compote` run in the build phase (F12) |
| Test scripts | `publish-pins.test.sh`, `publish-readonly.test.sh`, `publish-gate.test.sh` hook | no real credential; builds under `PACKBIN_BUILD_ONLY=1`; the readonly test's container probes write only into `/src` (expecting refusal) and its own `/out/artifacts/<lang>`; pip downloads are read-only. **(d) verified: no registry write path added** |
| Token on argv | see `static_analysis.md` | six sites, unchanged (F16) |

## Containers (F13)

| Check | Result |
|-------|--------|
| Merged compose config | `docker compose -f docker-compose.test.yml -f docker-compose.publish.yml --project-directory . config --format json` (Compose v2.24.3): `csharp`, `typescript`, `python`, `rust`, `cpp`, `java` each have `/src` bind of the repo with `read_only: true`, `/fixture/golden.hex` bind read-only, `/test-results` tmpfs. `cpp-embedded` and `cpp-embedded-esp` stay read-write; they run only in the `embedded` test job. The override lists the six by hand (a seventh service added to the base file would stay read-write; the config test checks the same fixed list) |
| What a build container can still write | its own `artifacts/<lang>` bind at `/out/artifacts/<lang>` (host directory); `/test-results` (tmpfs, memory); the container root filesystem, `/tmp`, `$HOME` (discarded with `--rm`). It cannot see the other languages' folders (`ls /out/artifacts` lists only its own, asserted by `publish-readonly.test.sh`), a script, a source file or `.git` |
| What it can still do | read all of `/src`, including `/src/.git/config` (names the checkout credential file); run as root with default capabilities, no `no-new-privileges`, no seccomp change; open outbound connections on the default bridge (needed by `npm ci`, pip and the compiler caches) |
| What the host still runs or reads from a container-written folder | `publish-check.py` (parses archives into memory; no `lstat`, no symlink or file-type check, `:100-175`), `publish-sign.sh:30-53` (signs, hashes and zips the Java tree; writes `.asc`, `.md5`, `.sha1` through planted symlinks; `find -type f` skips links, `rglob` plus `is_file()` includes them), `twine upload artifacts/python/*` (every file in the folder), `dotnet nuget push` and `npm publish` of fixed names, and `cargo publish --no-verify --allow-dirty --manifest-path artifacts/rust/stage/Cargo.toml`, which re-archives the whole `stage/` tree and follows file symlinks (probe). The checked object for Rust is the `.crate`, the uploaded object is the re-archived `stage/`; only `stage/Cargo.toml`'s version and the absence of `stage/target` are checked (`publish-check.py:135-138`). vcpkg, Arduino, PlatformIO and ESP-IDF are built on the host from the repository, not in a container, and their folders are made by the host |
| Digest between check and upload | none recorded (`build.log` is `build ok <target>`). Reduced: nothing but the host's own scripts and the pinned pip tools run between the container's exit and the upload, and a container is gone (`--rm`) before its folder is checked. Not closed |
| Ownership | `publish-inside.sh:33` chowns the folder to the host user inside the container; the loop 14 `chmod -R a+rwX` is gone. Linux ownership is proven only by the first CI run (Docker Desktop cannot show it) |
| C# pack from a copy | `publish-inside.sh:50-58`: verified on a scratch tree, see `static_analysis.md` |
| Image pinning | tags only: `mcr.microsoft.com/dotnet/sdk:10.0`, `node:24`, `python:3.14`, `rust:1.98`, `gcc:16`, `eclipse-temurin:26-jdk`, `espressif/idf:v5.3.2`, `ubuntu:24.04` (F3, unchanged). These are now the trust base of the build phase: a moved tag is the remaining route into F13 |
| Local note | a `.env` file exists untracked in the working tree of the audit host (not read); every test container mounts the repo root, so on a developer machine it is readable by test code. CI has none, and a laptop publish is forbidden (`restrictions.md`) |

## Network and registry traffic

Unchanged from loop 14: all registry calls HTTPS with default verification, no `-L`, `--max-time 20` on queries. New read-only traffic: pip to `pypi.org` for the pinned wheels (`--only-binary=:all:`), `npm` registry for `npm@11.21.0`.

## Findings carried and new

F1 fixed. F2 (`examples.sh:26-28,66`), F3 (images by tag, `apt-get` unpinned) carried. F12 reduced (Medium), F13 reduced (Low), F14, F15, F16 carried; F17 and F10 are library findings. Details in `security_report.md`.

## Earlier loops (condensed)

Loop 10: `cpp/embedded/Dockerfile` base by tag, packages from the distribution, no secrets; `examples.sh` downloads `arduino-cli` 1.1.1 with no checksum (F2). Loop 11: F3 extended to the six test images. Loop 13: toolchain cache moved to the gitignored `.cache/embedded/`; the gate test generates its GPG key into a `mktemp` keyring. Loop 14: `timeout-minutes` on every job; build phase credential stripping; F12 to F16 recorded.
