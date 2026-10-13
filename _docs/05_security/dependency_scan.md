# Dependency scan

**Date**: 2026-10-06
**Scope**: loop 16 (`git diff 9db438e..HEAD`, HEAD 5c95950; the owner's uncommitted C# and CI hunks are not part of it). New or changed supply-chain inputs: the npm package now ships a `tsc` build (`typescript/package.json`, `tsconfig.build.json`), three new actions in the `ring` job (`test.yml`), the vcpkg port (vendored sources), the `gcc:16` image used as the ring compiler. `tool-pins.txt`, `python/pyproject.toml`, `rust/Cargo.toml`, `java/api-check.sh` and `docker-compose.test.yml` are unchanged since loop 15 (`git diff` empty). Earlier loops condensed below.

## What ran and what could not

| Tool | Result |
|------|--------|
| `npm audit` and `npm audit --omit=dev` (registry reachable, on a `git archive HEAD` copy) | 0 vulnerabilities. `package-lock.json`: `@noble/hashes` 2.4.0 (runtime, exact pin) and `typescript` 5.9.3 (dev, `^5.9.2` locked); both resolved from `registry.npmjs.org` with `integrity`; no entry has `hasInstallScript` |
| `dotnet list package --vulnerable --include-transitive` on the HEAD copy of `csharp/tests/Packbin.Tests.csproj` (nuget.org) | "has no vulnerable packages given the current sources" (xunit 2.9.3, Microsoft.NET.Test.Sdk 17.14.1, coverlet.collector 6.0.4, xunit.runner.visualstudio 3.1.4). `Packbin.csproj` has no package reference; the two driver projects only reference `Packbin.csproj` |
| `cargo audit` (0.21.1) | **cannot run**: `unsupported CVSS version: 4.0` while loading the advisory database (`RUSTSEC-2026-0073`, libcrux-poly1305), as in loops 13 to 15. Nothing to audit anyway: `rust/Cargo.lock` and both driver lockfiles (`.github/workflows/drivers/{handoff-rust,rust}/Cargo.lock`) list only `packbin` and the path-dependent driver crate |
| `pip-audit`, `safety`, OWASP dependency-check, `osv-scanner`, `trivy`, `govulncheck`, `gitleaks`, `semgrep`, `shellcheck` | not installed on this host. Substituted: OSV `/v1/querybatch` (below), `bash -n` over every shell script in the repository (all parse), a grep of the loop 16 diff for key, token and private-key patterns (no hit), `.env` and key files are not tracked (`git ls-files`) |
| OSV `/v1/querybatch` (read-only) | 0 advisories for `npm` 11.21.0, `twine` 7.0.0, `platformio` 6.2.0, `idf-component-manager` 3.1.2, `build` 1.6.1, `setuptools` 84.0.0, `pytest` 9.1.1, `@noble/hashes` 2.4.0, `typescript` 5.9.3, the four NuGet test packages, and `packbin` 0.1.0 on npm, PyPI and crates.io. The 61-package wheel closure of the pinned tools was **not** re-resolved: the pins file is unchanged since loop 15, whose same-day query found 0 advisories |
| `python/pyproject.toml` | `dependencies = []`; `setuptools>=61` backend held at 84.0.0 by `PIP_CONSTRAINT` in the publish container (unchanged) |
| `java/`, `cpp/` | no package references; `java/api-check.sh` jars pinned by SHA-256 (unchanged) |

## GitHub Actions (`git ls-remote --tags`)

Every non-local `uses:` is a 40-hex commit with a tag comment, and every SHA equals its tag today:

| Action | Pin | Tag checked | Where |
|--------|-----|-------------|-------|
| `actions/checkout` | `3d3c42e5...90b1` | v7.0.1 = same commit | `test.yml:17,63,92`, `publish.yml:29` |
| `actions/setup-node` | `82076278...0fe5020` | v7.0.0 = same commit | `test.yml:96`, `publish.yml:32` |
| `actions/setup-dotnet` (new) | `a98b5685...c68` | v6.0.0 = same commit | `test.yml:93` |
| `actions/setup-python` (new) | `5fda3b95...4b97` | v7.0.0 = same commit | `test.yml:99` |
| `actions/setup-java` (new) | `de7274f0...e2e6` | v6.0.1 = same commit (lightweight tag) | `test.yml:102` |
| `NuGet/login` | `8d196754...1028841` | v1.2.0 and the peeled `v1` = same commit | `publish.yml:37` |

Not checked: that each commit is reachable from the action repository's default branch (a fork-network commit would resolve too); newer releases exist for none that was probed beyond these tags. The three new actions run only in the `ring` job, which has no secret and `contents: read`.

## Other inputs

| Source | Result |
|--------|--------|
| npm tarball content (new) | built `dist/` from `tsc` 5.9.3 inside the publish container (`publish-inside.sh:63-66`: `npm ci --ignore-scripts`, then `npm run build`); a scratch `npm pack` of the HEAD tree holds 26 files (`dist/*.js`, `dist/*.d.ts`, `package.json`, `README.md`), no `src/`, no test, no source map, no absolute path; `publish-check.py typescript` printed `check ok`; the built `dist/index.js` loads in Node 22 (31 exports). Runtime dependency is the one pinned `@noble/hashes` |
| vcpkg port (new) | vendored `CMakeLists.txt`, `LICENSE`, `include/`, `src/` copied from the checkout by the host script (`publish-embedded.sh:55-87`); the port downloads nothing at install. A consumer pins the registry by commit (`baseline` in `vcpkg-configuration.json`, `README.md:404-420`), and the `versions/p-/packbin.json` `git-tree` fixes the port content |
| Container images | tags, not digests (F3): `gcc:16` is now also pulled by the `ring` job (`test.yml:112`) and used as the compiler of the cross-language ring |
| `cpp/embedded/examples.sh:29-31,71-72` | `arduino-cli` 1.1.1 downloaded with `curl -fsSL` and unpacked without a checksum; the `esp32:esp32` core installed without a version (F2, lines moved by the error-handling edit) |
| `rustup toolchain install 1.98` (new, `test.yml:107-110`) | official channel, exact version, no checksum pin; test job without secrets |

No known-vulnerable dependency. No Critical or High.

## Earlier loops (condensed)

- Loop 15: tool pins (`tool-pins.txt`) verified on PyPI and npm, 61-package wheel closure 0 advisories, five actions pinned and verified (F1 fixed), `cargo audit` CVSS 4.0 failure, `npm audit` 0, `dotnet list package --vulnerable` 0.
- Loop 14: `twine`, `platformio`, `idf-component-manager`, `build` unpinned, 0 advisories; `java/api-check.sh` jars equal Maven Central's checksums.
- Loop 13: `npm audit` 0; `dotnet list package --vulnerable --include-transitive` none; `cargo audit` failed on CVSS 4.0.
- Loop 11: `typescript`, `rust`, `python`, `csharp`, `java` unchanged; no vulnerable package. Loop 10: C++ core has no dependencies; `arduino-cli` without checksum (F2).

## Loop 17 addendum (2026-10-07)

Scope: `csharp/` only (`git diff 68ca4f8..HEAD`). `dotnet list <project> package --vulnerable --include-transitive` against nuget.org: `csharp/Packbin.csproj` and `csharp/tests/Packbin.Tests.csproj` both report "has no vulnerable packages given the current sources". The only dependency the package has is `System.Memory` 4.6.3, referenced for the `netstandard2.0` build only (`68ca4f8`); the `net10.0` build has none. No package was added or changed in loop 17 batches. The other five packages are unchanged since the loop 16 scan.

## Loop 18 addendum (2026-10-11)

Scope: `git diff aea6344..HEAD -- csharp typescript python rust java cpp fixtures .github` (HEAD cd23293). No manifest, lockfile, Dockerfile, compose file or workflow pin changed in the range (the only project file touched is `.github/workflows/drivers/csharp/Position.csproj`, one `Compile Remove` line). A short confirmation, run on a `git archive HEAD` copy:

| Tool (date 2026-10-11) | Result |
|------|--------|
| `npm ci --ignore-scripts`, then `npm audit --json` and `npm audit --omit=dev` (registry reachable) | 0 vulnerabilities in every severity; 2 packages in the tree, `@noble/hashes` 2.4.0 and `typescript` 5.9.3 (`npm ls --all`) |
| `dotnet list csharp/Packbin.csproj package --vulnerable --include-transitive` and the same for `csharp/tests/Packbin.Tests.csproj` (`MSBUILDDISABLENODEREUSE=1`, nuget.org) | both "has no vulnerable packages given the current sources" (`System.Memory` 4.6.3 for `netstandard2.0` only) |
| OSV `/v1/query` (read-only) for `@noble/hashes` 2.4.0, `typescript` 5.9.3, `System.Memory` 4.6.3 | `{}` (no advisory) for all three |
| `cargo audit` 0.21.1 | cannot run, same error as loops 13 to 17 (`unsupported CVSS version: 4.0` in RUSTSEC-2026-0073); `rust/Cargo.lock` holds one package, `packbin` itself, so there is nothing to scan |
| Python | `python/pyproject.toml` has `dependencies = []`; `pip-audit` is not installed; nothing to scan. The wheel closure of the publish tools is unchanged since loop 15 (not re-resolved) |
| Java, C++ | no manifest and no dependency (the vcpkg port vendors `cpp/`); nothing to scan |

Not run: `pip-audit`, `osv-scanner`, `govulncheck`, `shellcheck`, OWASP dependency-check (not installed). Loop 12 to 17 findings F2 (arduino-cli checksum), F3 (images by tag) and F12 (unpinned wheels in the credentialed job) are unchanged. No CVE or advisory applies to anything the repository pulls in; Critical and High: none.

## Loop 19 (2026-10-11)

Scope: `git diff e1a791e..HEAD`. No manifest, lockfile, image or pin changed (`git diff e1a791e..HEAD --stat` over `typescript/package.json`, `package-lock.json`, `csharp/Packbin.csproj`, `rust/Cargo.toml`, `Cargo.lock`, `python/pyproject.toml`, the compose files, `cpp/embedded` and `.github/` lists only `run-suite.sh`, `run-suite.test.sh` and `test.yml`).

| Tool | Result |
|------|--------|
| `npm audit` (lockfile of a `git archive HEAD` copy) | 0 vulnerabilities |
| `dotnet list package --vulnerable --include-transitive` (`csharp/Packbin.csproj`, nuget.org) | "has no vulnerable packages given the current sources" |
| `cargo audit`, `pip-audit`, `govulncheck` | not run (as in loop 18: `cargo audit` 0.21.1 cannot parse the advisory database; Rust, Python, Java and C++ have no third-party dependency to scan) |

F2, F3 and F12 unchanged. No CVE or advisory applies.

## Loop 20 (2026-10-12)

No manifest, lockfile, image, workflow or publish script changed since loop 19 (`git diff --stat a27433e..HEAD` over everything outside the six package directories, `fixtures` and `_docs` lists nothing; inside the package directories no `*.csproj`, `package.json`, lockfile, `Cargo.toml`, `pyproject.toml` or Dockerfile changed, only `cpp/Makefile` gained a test file in `HOST_TESTS`).

| Tool | Result |
|------|--------|
| `npm audit --package-lock-only` (HEAD copy of `typescript/`) | found 0 vulnerabilities |
| `dotnet list package --vulnerable --include-transitive` (`csharp/Packbin.csproj`, nuget.org) | "has no vulnerable packages given the current sources" |
| `cargo audit`, `pip-audit`, `govulncheck` | not run (as in loop 19; Rust, Python, Java and C++ have no third-party dependency to scan) |

F2, F3 and F12 unchanged. No CVE or advisory applies.

## Loop 24 (2026-10-13)

Scope: `git diff 0db6534..HEAD` (HEAD ed30ddf, the Go package). The only manifests that changed are the Go module's `go/go.mod` and `go/go.sum` and the ring driver's `.github/workflows/drivers/handoff-go/go.mod` and `go.sum`; no `package.json`, `*.csproj`, `Cargo.*`, `pyproject.toml`, tool pin or Dockerfile changed (`git diff --name-only` filtered for them lists only the four Go files). The new image reference is `golang:1.27` (compose `go` service, `ring-go.sh`; Go 1.27.2 today). Run in `golang:1.27` on a `git archive HEAD` copy (network read-only).

| Module | Version | Where | Result |
|--------|---------|-------|--------|
| `golang.org/x/crypto` | v0.58.0 (direct) | `go/go.mod`, driver `go.mod` (`// indirect`) | latest on proxy.golang.org (`@latest`, 2026-10-09); `go.sum` `h1:` and `/go.mod h1:` lines equal `sum.golang.org/lookup/golang.org/x/crypto@v0.58.0`; imported packages `x/crypto/chacha20` and `x/crypto/internal/alias` only (`go list -deps`, linux/arm64); OSV `/v1/query` (Go ecosystem): **GO-2026-5932**, "The golang.org/x/crypto/openpgp package is unmaintained, unsafe by design" (introduced 0, no fixed version, affects `x/crypto/openpgp*` packages only); `govulncheck` 1.9.0: 0 vulnerabilities affect the code, 1 in a required module (this one), "doesn't appear to call". Not affected: nothing imports `openpgp`. |
| `golang.org/x/sys` | v0.49.0 (indirect) | `go/go.mod` | latest (`@latest`, 2026-10-06); `go.sum` lines equal sumdb's; OSV `/v1/query`: no advisory; no x/sys package is built on linux/arm64 (the `chacha20` path of other architectures, for example s390x, imports `x/sys/cpu`; not built here) |
| `golang.org/x/net` v0.60.0, `x/term` v0.47.0, `x/text` v0.43.0 | n/a | module graph via x/crypto's `go.mod` (`go list -m all`) | pruned: not downloaded, not built, no `go.sum` line; the `run-suite.sh go` step `go_deps` checks that the built packages and the direct requirements are only the main module and x/crypto |

| Tool (2026-10-13) | Result |
|-------------------|--------|
| `go mod verify` (module cache of the build) | all modules verified |
| `govulncheck` 1.9.0 (`go run golang.org/x/vuln/cmd/govulncheck@latest -C go ./...`) | "No vulnerabilities found" in symbols and packages; one module-level advisory (GO-2026-5932), not called |
| OSV `https://api.osv.dev/v1/query` POST for x/crypto 0.58.0 and x/sys 0.49.0 (ecosystem Go) | one advisory and none, as above |
| `go.sum` against `https://sum.golang.org/lookup/<module>@<version>` | both modules: all four lines equal |
| `https://proxy.golang.org/github.com/zxsanny/packbin/go/@v/list` | 404 `no matching versions`: the module is not published yet (nothing tagged), so no one can hold the path; the first tag is the publish |
| `npm audit`, `dotnet list package --vulnerable`, `cargo audit`, `pip-audit` | not re-run: no manifest of those ecosystems changed since the loop 20 results |

| Action / image | Pin | Check |
|----------------|-----|-------|
| `actions/setup-go` (new, `test.yml:112`, `publish.yml:35`) | `b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0` | `git ls-remote https://github.com/actions/setup-go refs/tags/v7.0.0` = the same commit (lightweight tag); `publish.yml` sets `cache: false`, `test.yml` caches `go/go.sum` and the driver's `go.sum` (no cache in the credentialed job) |
| `golang:1.27` | tag | by tag, not digest: F3 extended; `GOTOOLCHAIN=local` and `GOPROXY=https://proxy.golang.org,direct` inside |
| `go-version: "1.27"` (`publish.yml:37`, `test.yml`) | floating patch | resolved by the action's manifest at run time; F12 note |

Findings: no known-vulnerable dependency that the code reaches; F2, F3 (extended), F12 (touched), F1 unchanged (fixed). No Critical or High.
