# Component 07 — CI and publish

**Run**: `02-whole-project-assessment` (Quick Assessment, Phase 1, read-only)
**Tree**: `loop/10-cpp-microcontroller` at `d108141`
**Scope**: `.github/workflows/test.yml`, `publish.yml`, the 13 shell scripts beside them, `docker-compose.test.yml`, `.dockerignore`, `.gitignore`, `.env.example`.
**Method**: full read of every file; `grep` inventories (env vars, literals, `/dev/null`, `|| true`, `case "$lang"`); `git log` / `git tag` on the publish files. `shellcheck` is not installed on this host, so the bash review is manual against `~/.claude/rules/bash.md`. The local `.env` (mode 600, gitignored) was not read.

## 1. Files and size

| File | Lines | Role |
|------|-------|------|
| `test.yml` | 57 | Two jobs: `scaffold` (file checks, report-row test, six suites in a loop, publish-gate tests) and `embedded` (`cpp/embedded/run.sh`) |
| `publish.yml` | 49 | On a `v*` tag: gate, setup-node + npm@11, `NuGet/login@v1`, crates.io OIDC exchange, publish, revoke |
| `run-suite.sh` | 74 | Per-language suite inside its compose service; writes one report row |
| `report-row.sh` / `report-row.test.sh` | 22 / 24 | CSV row writer (flock) and its test |
| `publish-lib.sh` | 71 | `PACKBIN_LANGS`, presence checks, `push_branch` (askpass), `byte_mismatch` |
| `publish-gate.sh` | 56 | Packs the position row in every present language (in containers) and writes the publish plan |
| `publish-position.sh` | 61 | Builds and runs one position driver |
| `publish-registries.sh` | 313 | Credential checks, plan filtering, vcpkg port, PyPI/npm OIDC, Maven sign/zip/upload/poll, dispatch |
| `publish-inside.sh` | 114 | In-container pack/upload for NuGet, npm (token), PyPI (token), crates, Java bundle |
| `publish-embedded.sh` | 99 | PlatformIO, ESP-IDF registry, Arduino branch/tag |
| `stage-arduino.sh` | 23 | Arduino library layout (also used by the embedded examples target) |
| `crates-token.sh` | 86 | crates.io trusted-publishing exchange and revoke |
| `language-pair.sh` | 110 | Six-language handoff ring (user, nested, session) and position — **not run by any workflow** |
| `publish-gate.test.sh` | 403 | Static greps, crates token, registry dry runs, gate scenarios, Maven bundle, manifests, workflow greps |
| `docker-compose.test.yml` | 104 | Six suite services + `cpp-embedded` (built) + `cpp-embedded-esp` |

All files are under the 500-line soft cap. Largest: `publish-gate.test.sh` 403, `publish-registries.sh` 313.

## 2. Flows

### Test (every push and pull request)

`scaffold` job: file-existence checks → `report-row.test.sh` → `for lang in …; docker compose run --rm $lang` (stops at the first failing language) → `publish-gate.test.sh` (runs `publish-gate.sh` three times = 17 container driver builds, plus one Java bundle container). `embedded` job: `cpp/embedded/run.sh` (builds the embedded image, then the arm and esp stages; ~40 min cold).

Not run anywhere in CI: `language-pair.sh` (six-language handoff and session ring; `_docs/loops/loop09/test-run09.md:12` says so), any linter or type checker (`typescript/package.json:18` runs `node --test` only; `tsc` is installed but never invoked), any coverage collector.

### Publish (tag `v*`)

```
publish-gate.sh  ──(mismatch>0 → exit 1, plan empty)──▶ stop
   │ plan = present languages
   ▼
setup-node, npm@11, NuGet/login (OIDC), crates-token exchange (OIDC)
   ▼
publish-registries.sh
   need(): NuGet token, npm token-or-OIDC, Maven token + GPG key   ← fail before any write
   skip:   python (no token, no OIDC), rust (no token)              ← silent subset
   loop csharp → typescript → python → rust → cpp(vcpkg + publish-embedded) → java
        each step uploads immediately; java bundle is built and signed only at the end
   ▼
crates-token revoke (always)
```

What the gate guarantees: no registry write happens unless every present language's position driver prints the golden hex (fails closed on a driver build failure, because empty output counts as 13 mismatched bytes). The gate step precedes credentials and uploads (`publish.yml:17-18` before `:44`; asserted by `publish-gate.test.sh:33-38`).

What it does not guarantee:

1. **Tests green on the tagged commit.** `publish.yml` does not depend on `test.yml`; the docs list it as a release precondition (`deployment_procedures.md:5`, `system-flows.md:138`).
2. **All-or-nothing upload.** Uploads are sequential; a failure after the first write leaves a partial release. Re-runs are not idempotent: `npm publish`, `twine upload` (no `--skip-existing`) and `cargo publish` fail on an existing version; only NuGet uses `--skip-duplicate`. The Java bundle (the slowest, most failure-prone step: GPG import, signing, Central polling up to 90 × 15 s) runs last, after five registries were written. Evidence of the cost: tags `v0.1.1`–`v0.1.8` were cut on 2026-09-23/24, most of them publish fixes (`git tag` subjects: "Let the runner sign the Maven bundle", "Publish Java under io.github.zxsanny", "Retry a crates.io revoke…").
3. **Every present language publishes.** Python, Rust and the three embedded registries are skipped with a one-line `skip X` when their credential is absent; the job stays green (`publish-registries.sh:43-59`, `publish-embedded.sh:47-58,73-76`). Contradicts ADR-002 "A bad golden check cannot ship five languages and skip one" in spirit and AC-12 "publishes 1 package per language present".
4. **What ships is what was checked.** The gate runs drivers against the source tree; the uploaded artifacts (nupkg, npm tarball, wheel, crate, jar, PlatformIO archive) are built separately and never re-checked. The embedded examples target does build from the packaged layouts.

## 3. Findings

| # | Finding | Evidence | Class | Severity |
|---|---------|----------|-------|----------|
| F1 | Java jar is compiled by `javac` from `eclipse-temurin:26-jdk` with no `--release`, so Maven Central gets class-file version 70; Java 17/21 and Android consumers cannot load it | `publish-inside.sh:67`, `docker-compose.test.yml:68`; no `--release`/`-target` anywhere (`grep`) | logic bug | High (verify with `javap -v` on the published jar) |
| F2 | vcpkg port copies `src/` into `share/packbin/src` and builds nothing; the core's `pack_table`/`unpack_table`/session are in `src/core/*.cpp`, so a vcpkg consumer gets unresolved symbols; no CMake target is exported though README promises one | `publish-registries.sh:80-100`; `cpp/include/packbin/codec.hpp:65-67`; `README.md:329` | logic bug | Medium-High |
| F3 | Publish not gated on tests | `publish.yml` (no `needs`/`workflow_call`) | design contradiction | Medium |
| F4 | Partial publish + non-idempotent re-run | §2 item 2 | logic bug / design | Medium-High |
| F5 | Silent subset publish when a credential is missing | §2 item 3 | design contradiction | Medium |
| F6 | OIDC/trusted publishing used for NuGet, crates.io, PyPI, npm while ADR-002, R-19 and architecture say credentials stay in the secret store and OIDC was "not selected" | `publish.yml:24-30`, `crates-token.sh`, `publish-registries.sh:153-213` | documentation drift / design contradiction | Medium |
| F7 | `language-pair.sh` never runs in CI | no caller in workflows; `test-run09.md:12` | CI gap | Medium |
| F8 | No lint, type check or coverage in CI; docs claim lint runs | `test.yml`; `_docs/02_document/deployment/ci_cd_pipeline.md:12`; `quality-thresholds` 75/90 cannot be checked | CI gap | Medium |
| F9 | Declared minimum versions are not tested: Python `>=3.10` (CI 3.14), Node `>=22` (CI 24), ESP-IDF `>=5.1` (CI 5.3.2) | `python/pyproject.toml:7`, `typescript/package.json:24`, `cpp/idf_component.yml:7` | CI gap | Low-Medium |
| F10 | Bind mount `./:/src` shares host build outputs with Linux containers (`cpp/build`, `rust/target`, `csharp/**/obj`, `typescript/node_modules`, driver `bin/obj`); `make` treats a macOS binary as up to date | `docker-compose.test.yml:12,25,…`; `LESSONS.md:30`; baseline obs. 4 | logic bug (local) | Medium |
| F11 | `publish-gate.test.sh` runs the gate 3× (17 cold container driver builds) and `copy_tree` copies build/cache dirs (`cpp/build/embedded` toolchains, `handoff-rust/target`, `node_modules`, `bin/obj`) three times | `publish-gate.test.sh:118-127,129-177` | performance waste | Low-Medium |
| F12 | Test-only knobs live in the publish scripts (`PACKBIN_DOCKER`, `PACKBIN_MAVEN_BUNDLE_ONLY`, `PACKBIN_PLAN`, `PACKBIN_WORK`, `PACKBIN_FIXTURE`); `PACKBIN_WORK` and `PACKBIN_FIXTURE` are set by nothing | `grep` | S08 | Low |
| F13 | npm token path is dead in CI: `publish.yml` never passes `NPM_TOKEN`, OIDC is always present, so `publish-inside.sh typescript` and the NPM_TOKEN checks only serve a laptop publish, which R-15 forbids; `.env.example` invites registry tokens on a laptop | `publish.yml:33-43`, `publish-inside.sh:23-30`, `.env.example` | S07 / design contradiction | Low |
| F14 | `.env.example` lacks `PLATFORMIO_AUTH_TOKEN`, `IDF_COMPONENT_API_TOKEN`, `GITHUB_TOKEN`, `VCPKG_REGISTRY_URL`, `ARDUINO_REGISTRY_URL` | `.env.example`, `publish.yml:41-43` | config drift | Low |
| F15 | Duplicated logic: version rewrite Python snippet ×3 (`publish-inside.sh:35-41,50-56`, `publish-registries.sh:159-165`); OIDC token fetch ×2 (`crates-token.sh:17-21`, `publish-registries.sh:173-181`); npm and PyPI publish each implemented twice (token path in container, OIDC path on host); git identity ×2; repo URL/owner ×8 | `grep` | S06 | Low-Medium |
| F16 | Unpinned tools in the publish path: `pip install build twine`, `platformio`, `idf-component-manager`, `pytest`, `npm@11`; actions pinned by major tag (`actions/checkout@v7`, `actions/setup-node@v7`, `NuGet/login@v1`) in a job with `id-token: write` and `contents: write` | `publish-registries.sh:167`, `publish-inside.sh:42`, `publish-embedded.sh:51,60`, `run-suite.sh:38`, `publish.yml` | supply chain | Medium |
| F17 | Secrets on argv (`twine -p`, `cargo --token`, `nuget --api-key`); npmrc and GPG keyring temp dirs never removed (no `trap`) | `publish-registries.sh:199,227`, `publish-inside.sh:19,28,57` | S28 hygiene | Low (GitHub masks logs; runner is ephemeral) |
| F18 | `crates-token.sh revoke` returns 0 on 4xx and after 5 failed attempts — a token that was not revoked leaves the job green | `crates-token.sh:48-77` | S25 (by design: the token is short-lived) | Low |
| F19 | `run_inside` hardcodes the container `PACKBIN_OUT=/src/.github/workflows/out` while the host uses `$out`; with `PACKBIN_OUT` set, the Java bundle is "missing" | `publish-registries.sh:17,72`, `:217-219` | latent logic bug | Low |
| F20 | `test.yml` suites loop stops at the first failing language; one job, no matrix, no cache, no `timeout-minutes`; push + pull_request run twice on PR branches; embedded job runs on every change (docs-only included) | `test.yml:36-42,46-57` | performance waste / CI design | Medium |
| F21 | Default version `0.1.0` when `PACKBIN_VERSION` is unset (`publish-embedded.sh` requires it instead) | `publish-registries.sh:14`, `publish-inside.sh:10` | S21 risky default | Low |
| F22 | Golden hex literal copied 4× in CI files beside its SoT `fixtures/golden.hex`; `run-suite.sh:11` and `test.yml:33` compare the fixture to their own copy | `grep` | S20/S06 | Low |
| F23 | `language_present` is a marker-file convention (`java/test.sh`, `cpp/Makefile`, `csharp/*.csproj`…); the gate takes the **last non-empty stdout line** of a driver as its hex | `publish-lib.sh:12-25`, `publish-gate.sh:28-30` | S32 | Low (documented nowhere) |
| F24 | `publish-gate.test.sh` asserts source text of other scripts (`grep -q 'push_branch "$1" "$2" vcpkg'`, `grep -q 'set -euo pipefail' test.yml`) — brittle, passes on a comment | `publish-gate.test.sh:20-49,238-252,373-379` | S12 / test smell | Low |

## 4. Bash rule review (manual; shellcheck unavailable)

- Strict mode: all scripts `set -euo pipefail` except `run-suite.sh` (`set -uo pipefail`, deliberate status collection; `report-row.sh` failure is then ignored).
- `/dev/null`: only probes (`command -v`, `compgen -G`, `git init`/`show` in tests) and `curl -o /dev/null` for a status code — compliant.
- `|| true`: `crates-token.sh:58` (curl transport error becomes code `000`, retried) and `publish-gate.test.sh:138` (`grep -c`) — acceptable.
- No `case` inside process substitution. Heredocs quoted where they carry shell text (`<<'EOF'`, `<<'PY'`); the vcpkg.json/POM heredocs are unquoted on purpose (version expansion).
- Quoting issue: `run-suite.sh:30` builds a command string with `'$root/typescript'` inside `bash -lc "…"` (breaks on a `'` in the path; `-l` is unnecessary).
- Fixed `/tmp` paths instead of `mktemp`: `run-suite.sh:35`, `language-pair.sh:28,40`, `publish-position.sh:31,35,47`.
- Inconsistent defaults for the same knob: `${CXX:-c++}` (`language-pair.sh:34`) vs `${CXX:-g++}` (`publish-position.sh:41`); `FIXTURE` (`run-suite.sh`) vs `PACKBIN_FIXTURE` (`publish-gate.sh`).

## 5. Image and version pins

| Where | Tag | Pinning |
|-------|-----|---------|
| compose `csharp` | `mcr.microsoft.com/dotnet/sdk:10.0` | minor-floating (restriction: current LTS) |
| compose `typescript` | `node:24` | major-floating |
| compose `python` | `python:3.14` | minor-floating |
| compose `rust` | `rust:1.98` | minor-floating |
| compose `cpp` | `gcc:16` | major-floating |
| compose `java` | `eclipse-temurin:26-jdk` | major-floating, non-LTS JDK used to build the published jar (F1) |
| compose `cpp-embedded` | built from `ubuntu:24.04`, apt packages unpinned | base pinned to release |
| compose `cpp-embedded-esp` | `espressif/idf:v5.3.2` | exact |
| `publish-gate.test.sh:207` | `ubuntu:24.04` | release |
| workflows | `actions/checkout@v7`, `actions/setup-node@v7`, `NuGet/login@v1` | major tag, not SHA |

Floating majors match the restriction "current LTS / current stable at publish time" (`restrictions.md:11`), so they are `code-ok` for tests; for the publish job they make the artifact depend on the day's image (F1 is the concrete consequence).
