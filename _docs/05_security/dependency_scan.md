# Dependency scan

**Date**: 2026-09-23
**Scope**: product manifests (not `_docs/00_research/`)

| Manifest | Runtime dependencies | Tool | Result |
|----------|----------------------|------|--------|
| `typescript/package.json` | none | `npm audit` | no lockfile and no dependency entries |
| `python/pyproject.toml` | `dependencies = []` | manifest read | `pip-audit` is not installed; nothing to audit |
| `rust/Cargo.toml` | none, no `Cargo.lock` | `cargo audit` | advisory database failed to parse `CVSS:4.0` (`RUSTSEC-2026-0073`); the crate itself has no third-party dependencies |
| `csharp/Packbin.csproj` | none | `dotnet list package --vulnerable` | no packages |
| `csharp/tests/Packbin.Tests.csproj` | coverlet.collector 6.0.4, Microsoft.NET.Test.Sdk 17.14.1, xunit 2.9.3, xunit.runner.visualstudio 3.1.4 | `dotnet list package --vulnerable --include-transitive` | no vulnerable packages |
| C++ and Java | none | manifest read | no package manager dependencies |

No CVE findings.
