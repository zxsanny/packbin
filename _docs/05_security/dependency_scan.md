# Dependency scan

**Date**: 2026-10-06
**Scope**: loop 15 (`git diff b45335d..HEAD`, HEAD 4300410): the new tool pins (`tool-pins.txt`), the unchanged package manifests, the actions. Earlier loops condensed below.

## Loop 15

| Manifest / source | Tool | Result |
|-------------------|------|--------|
| `typescript/package.json`, `package-lock.json` | `npm audit` (registry reachable) | 0 vulnerabilities (`@noble/hashes` 2.4.0, dev `typescript`). Unchanged |
| `csharp/tests/Packbin.Tests.csproj` (scratch copy) | `dotnet list package --vulnerable --include-transitive` | "has no vulnerable packages given the current sources" (nuget.org). `Packbin.csproj` has no package reference |
| `rust/Cargo.toml`, `Cargo.lock` | `cargo audit` | cannot run: `unsupported CVSS version: 4.0` in the advisory database (as in loops 13 and 14). `Cargo.lock` lists only the crate itself, so there is nothing to audit |
| `python/pyproject.toml` | manifest read | `dependencies = []`; build backend `setuptools>=61` is now held by `PIP_CONSTRAINT=tool-pins.txt` (`setuptools==84.0.0`, the latest release; OSV: no advisory) |
| `java/`, `cpp/` | manifest read | no package references; `java/api-check.sh` unchanged (jars pinned by SHA-256, verified in loop 14) |
| `.github/workflows/tool-pins.txt` (new) | PyPI JSON, npm registry, OSV `/v1/query` | `twine` 7.0.0, `platformio` 6.2.0, `idf-component-manager` 3.1.2, `build` 1.6.1, `setuptools` 84.0.0, `pytest` 9.1.1: every version exists, has a `py3-none-any` wheel, is not yanked, has 0 PyPI-reported vulnerabilities and 0 OSV advisories. `npm` 11.21.0 exists, not deprecated, 0 OSV advisories (latest is 12.2.0; the pin is deliberately 11.x) |
| Transitive wheel closure of the pinned tools | `pip install --dry-run --report` (Python 3.14, macOS), `pip download --only-binary=:all: --platform manylinux2014_x86_64 --python-version 3.12` | `twine` 22 packages, `platformio` 23, `idf-component-manager` 28, `build` 3, `pytest` 5; 61 distinct packages in all, all resolved as wheels, also for Linux x86_64 and Python 3.12 (the runner's interpreter). OSV `/v1/querybatch` over the 61 name and version pairs: **0 advisories**. Not pinned and not hashed (F12): `requests` 2.34.2, `urllib3` 2.8.0, `pydantic` 2.13.5, `starlette` 1.7.0, `uvicorn` 0.54.0, `rich` 15.0.0, `nh3` 0.3.7, `psutil` 7.2.2, ... as resolved today |
| GitHub Actions | `git ls-remote --tags` | `actions/checkout` v7.0.1 = `3d3c42e5aac5ba805825da76410c181273ba90b1`, `actions/setup-node` v7.0.0 = `820762786026740c76f36085b0efc47a31fe5020`, `NuGet/login` v1.2.0 = `8d196754b4036150537f80ac539e15c2f1028841`: all equal the pins in the workflows (F1 fixed). `NuGet/login` and `setup-node` are `node24` actions that run a bundled `dist/index.js`, so the commit fixes their code |
| Container images (`docker-compose.test.yml`) | manifest read | tags, not digests (F3, unchanged) |
| `cpp/embedded/examples.sh:26-28,66` | manifest read | `arduino-cli` 1.1.1 by URL, no checksum; `esp32:esp32` core without version (F2) |

No known-vulnerable dependency. No Critical or High.

## Earlier loops (condensed)

- Loop 10: C++ core has no dependencies; `cpp/embedded/examples.sh` downloads `arduino-cli` without a checksum (F2).
- Loop 11: `typescript` (`@noble/hashes` 2.4.0), `rust`, `python`, `csharp`, `java` unchanged; no vulnerable package.
- Loop 13: `npm audit` 0; `dotnet list package --vulnerable --include-transitive` for `csharp/tests/Packbin.Tests.csproj` (xunit 2.9.3, Test.Sdk 17.14.1, coverlet 6.0.4, runner 3.1.4) and the `Handoff.csproj` driver: none; `cargo audit` failed on CVSS 4.0.
- Loop 14: `twine`, `platformio`, `idf-component-manager`, `build` unpinned, 0 advisories; `java/api-check.sh` jars equal Maven Central's checksums.
