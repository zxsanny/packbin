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

## Loop 18 addendum (2026-10-11)

Files changed under `.github/` and `fixtures/` in `aea6344..HEAD`, all read: `language-pair.sh` (C# joins the `listgroup`, `dictgroup` and `listflags` rings as producer and consumer, loop over the short packets now includes C#; the Java build now also requires `HandoffElements.class` and compiles `drivers/HandoffElements.java`), `drivers/csharp/HandoffElements.cs` (new), `drivers/csharp/Handoff.cs` and `Position.csproj` (one `Compile Remove`), `ring-wiring.test.sh` (80 new lines that check the C# lines and driver commands), `fixtures/hostile/check-cases.sh`, `cases.test.sh`, `cases.txt` and `README.md`. No workflow YAML, Dockerfile, compose file, image tag, secret, permission or publish script changed.

| Item | Result |
|------|--------|
| `check-cases.sh` against a hostile `cases.txt` and README (7 MB; `$(...)`, backticks, `;`, `&&`, `\|\|`, `* ? [a-z] ~ {a,b}`, `-n -e --`, ESC/BEL/CR/BS bytes, `::error::` text, 5 000-field line, 3 000 duplicate ids, 1 MB to 2.5 MB fields), bash 3.2.57 | no command ran (canary files under the probe directory: none created), no glob expanded (`set -f`, quoted expansions, no `eval`), exit 1 with 3 049 error lines in 10.8 s and 80 MB; every message starts `file:line:` so a `::` command cannot begin a line; the raw field is echoed (ESC/OSC sequences reach the log) |
| `cases.test.sh`, `ring-wiring.test.sh` on the archive copy, bash 3.2 | pass ("hostile case tests passed", "ring wiring checks passed"); the shim heredoc receives only `user_hex` (a `[0-9a-f]*` capture) and literals; the workflow is parsed with `YAML.safe_load` |
| `HandoffElements.cs:80` | `Convert.FromHexString(args[1])` can throw `FormatException`; inputs are the script's fixed hex constants and the producer output already compared to them; fail-closed |
| `language-pair.sh:65-68` (F24) | still reuses `/tmp/packbin-handoff-java` when both `Handoff.class` and `HandoffElements.class` exist; one more class file a local user could pre-create. Unchanged otherwise (`PACKBIN_JAVA_HANDOFF` still overrides) |

Findings F12, F13, F14, F15, F16, F20, F23, F24 unchanged (F24 as noted). Not run: the `ring` job on a runner, Docker, `shellcheck`, GNU bash 5.

## Loop 19 (2026-10-11)

Scope: `.github/workflows/run-suite.sh`, `run-suite.test.sh`, `test.yml` (one new step, `bash .github/workflows/run-suite.test.sh` in the `scaffold` job; the job's permissions and secrets are unchanged). No Dockerfile, compose file, publish script, pin or image changed.

| Item | Result |
|------|--------|
| `run-suite.sh` venv guard (`:40-49`) | A directory that exists, holds no `pyvenv.cfg` and is not empty is refused before `python -m venv --clear` (review C5 closed); a missing, empty or venv-shaped directory is rebuilt. Six hostile values of `PACKBIN_PYTEST_VENV` (`x; touch ...`, spaces, `$(...)`, backticks, quotes, `--help`) ran no code; `--help` fails closed |
| `run-suite.sh` default venv (`:37`) | F32: `/tmp/packbin-pytest` is a fixed shared name; `[ -e ]` follows a symlink and `python -m venv --clear` empties the target when it holds a `pyvenv.cfg` and no `bin/pytest` (probe); `bin/python` and `bin/pytest` of a pre-created directory are executed. Same family as F24; single-user runners are not affected |
| `run-suite.test.sh` | 5 checks (broken venv, usable venv with `-m pytest` called, failing pytest, non-venv directory kept, missing venv built with the pinned pytest), all with fake interpreters, no network; passes under bash 3.2. `work=$(mktemp -d ...)` has no failure branch (note in `security_report.md`) |
| `test.yml` | the new step runs a repository script with no secret and no write permission |

Findings F12, F13, F14, F15, F16, F20, F23, F24 unchanged; F32 new. Not run: the `ring` job, Docker, GNU bash 5, `shellcheck`.

## Loop 24 (2026-10-13)

Scope: `publish.yml`, `publish-go.sh`, `publish-lib.sh`, `publish-build.sh`, `publish-check.py`, `publish-upload.sh`, `publish-registries.sh`, `publish-position.sh`, `publish-query.sh`, `test.yml`, `ring-go.sh`, `ring-toolchains.sh`, `run-suite.sh`, `language-pair.sh` (Go lines), `docker-compose.test.yml`, `docker-compose.publish.yml`, the driver module. Method: `security_report.md`, "Loop 24 method".

| Item | Result |
|------|--------|
| Triggers and permissions | `publish.yml` triggers on tag pushes `v*` only, so a fork pull request never reaches it and `go/v*` does not match; `test.yml` (push, pull_request, workflow_call) has `contents: read` and no secret in any job; the `publish` job keeps `contents: write` and `id-token: write` (unchanged) and now installs Go with `setup-go` at the commit of v7.0.0 and `cache: false` |
| Go tag push (`publish-go.sh`, `git_push`) | `git push --atomic "$url" "$commit:refs/tags/$tag"`, never `--force`; token only through `GIT_ASKPASS` (a `mktemp` script that reads `$GITHUB_TOKEN`, `credential.helper=` emptied, `GIT_TERMINAL_PROMPT=0`), removed after the push; the commit comes from `prepare_go_tag` in the token-less build phase (`git rev-parse HEAD`, refused when `refs/tags/v$version` is at another commit or the checkout has no `.git`) and `publish-check.py go-tag` checks tag line, 40-hex commit, module line and MIT text before any write; remote asked first (peeled annotated tag, then plain): same commit pushes nothing, another commit fails naming both, absent pushes. Gap: F45 (version form), F44 (hand-pushed tags) |
| Order | `PACKBIN_TARGETS` puts `go-tag` in tier `final`; `publish-upload.sh` loops `required optional final` under `set -e`, so a failed upload of any target means no Go tag; `publish-registries.sh` refuses a `final` target without its credential before any write (`!= optional`); `go-tag` has no registry answer and always re-runs the proxy check |
| Proxy check | `GOPROXY=https://proxy.golang.org` (no `direct`), `GOFLAGS=-mod=mod`, `GOWORK=off`, `GONOSUMDB`, `GONOSUMCHECK`, `GONOPROXY`, `GOPRIVATE`, `GOINSECURE`, `GOSUMDB` unset, a fresh `mktemp -d` module; `go list -m "$module@v$version"` only reads metadata (no code runs); it runs in the step that holds every registry token (F12 note). It proves the proxy knows the version, not that `go get` works (F45) |
| Fork pull request | a fork PR runs `test.yml` with a read-only token and no secret; `ring-go.sh` and `run-suite.sh go` run its code in the runner or the `golang:1.27` container, as for the six other languages; the Go module cache of `setup-go` in the `ring` job is keyed by `go.sum` and scoped to the ref |
| `ring-go.sh` (new) | rebuilds only when a Go source, `go.mod` or `go.sum` is newer than `$out` (default `/tmp/packbin-handoff-go`, `/tmp/packbin-position-go` in the gate), else executes the existing binary: F24 extended. Without `go` (the owner's Mac) it runs `docker run --rm -i -v "$root:$root" [-v "$outdir:$outdir"] -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -e CGO_ENABLED=0 ... golang:${RING_GO:-1.27} go build`: repo and (by default) host `/tmp` read-write, root, default network, image by tag: F20 and F3 extended; it only builds, cgo off, `GOTOOLCHAIN=local` in the image; the volumes are written by `go build` downloads checked against `go.sum` |
| `run-suite.sh go` and the compose `go` service | `go -C "$root/go"` for fmt, vet, `test -race`, the speed test, `go test -fuzz` (60 s, `-fuzzminimizetime=0`) and the `go_deps` gate; a missing `go/go.mod` fails (the six others skip, assessment24 D6); the service mounts the repo read-write and `./test-results`, default network, root, image by tag; fuzz failures write into `go/testdata/fuzz/` as root; tests download x/crypto at run time from the proxy and verify it against the committed `go.sum` |
| Go module and replace directive | the published `go/go.mod` has no `replace`; the driver module's `replace github.com/zxsanny/packbin/go => ../../../../go` applies only to the driver (a consumer ignores it); `GOFLAGS=-mod=mod` appears only in the proxy check's probe directory |
| Secrets and credentials | no new secret, token, permission or registry write path; the Go tag push uses the existing `GITHUB_TOKEN`; nothing in the diff holds a key pattern |

Findings: F44 and F45 new (Low); F12, F14, F20, F24, F3 touched as listed in `security_report.md`; F1 stays fixed. Not run: the `ring` job, `publish-gate.test.sh`, `publish-go.test.sh`, the first real tag and proxy (none exists), repository settings.
