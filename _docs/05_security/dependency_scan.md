# Dependency scan

**Date**: 2026-10-05
**Scope**: loop 10, the C++ core and the embedded CI

| Manifest | Tool | Result |
|----------|------|--------|
| `cpp/library.json`, `cpp/idf_component.yml`, `cpp/CMakeLists.txt`, `cpp/arduino/library.properties` | manifest read | no dependencies. The core includes only `<cstdint> <cstddef> <cstring> <type_traits> <limits> <array> <utility>` and its own headers |
| `cpp/embedded/Dockerfile` | manifest read | Ubuntu 24.04 packages from the distribution: `gcc-arm-none-eabi`, `qemu-system-arm`, `qemu-user-static`, `g++-s390x-linux-gnu`. Build-time only; nothing ships to users |
| `cpp/embedded/examples.sh` | manifest read | downloads `arduino-cli` 1.1.1 from GitHub releases with no checksum (F2); PlatformIO and Python packages installed into a venv |
| `typescript`, `rust`, `csharp`, `python`, `java` | not changed in loop 10 | results of 2026-09-29 stand: no vulnerable packages |

The C++ core ships no third-party code.

## Loop 11 addendum

**Date**: 2026-10-05
**Scope**: Python, TypeScript, C#, Java and Rust unpack changes (`git diff 9a7847f..HEAD`)

| Manifest | Tool | Result |
|----------|------|--------|
| `typescript/package.json`, `package-lock.json` | manifest read | unchanged since loop 10: `@noble/hashes` 2.4.0, dev `typescript` |
| `rust/Cargo.toml`, `Cargo.lock` | manifest read | unchanged, no dependencies |
| `python/pyproject.toml`, `csharp/Packbin.csproj`, `java/` | manifest read | unchanged, no dependencies |
| all | `npm audit`, `cargo audit`, `dotnet list package --vulnerable` | not run: they need the network. Results of 2026-09-29 stand; no manifest changed |

## Loop 13 addendum

**Date**: 2026-10-06
**Scope**: loops 12 and 13 (`git diff 39d3a88..HEAD`); the registries were reachable this time

| Manifest | Tool | Result |
|----------|------|--------|
| `typescript/package.json`, `package-lock.json` | `npm audit` | 0 vulnerabilities (`@noble/hashes` 2.4.0, dev `typescript`) |
| `csharp/tests/Packbin.Tests.csproj` (xunit 2.9.3, Test.Sdk 17.14.1, coverlet 6.0.4, runner 3.1.4), `.github/workflows/drivers/csharp/Handoff.csproj` | `dotnet list package --vulnerable --include-transitive` | no vulnerable packages |
| `rust/Cargo.toml`, `Cargo.lock` | `cargo audit` | could not run: the installed 0.21.1 fails to parse a CVSS 4.0 advisory (`RUSTSEC-2026-0073`). `Cargo.lock` lists one package, the crate itself; the driver crate `.github/workflows/drivers/handoff-rust` depends only on it. Nothing to audit |
| `python/pyproject.toml` | manifest read | `dependencies = []` (build requires `setuptools>=61`) |
| `java/` | manifest read | no build file with dependencies; the JDK only |
| `cpp/` | manifest read | no dependencies |

No manifest or lockfile changed in loops 12 and 13. No vulnerable package; no finding.
