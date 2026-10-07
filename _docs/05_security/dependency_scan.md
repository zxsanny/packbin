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
