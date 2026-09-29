# Dependency scan

**Date**: 2026-09-29
**Scope**: loop 9, pack session

| Manifest | Tool | Result |
|----------|------|--------|
| `typescript/package.json` | `npm audit` | 0 info, 0 low, 0 moderate, 0 high, 0 critical. Dev dependency: `typescript` |
| `rust/Cargo.toml` | manifest | `[dependencies]` is empty. `cargo audit` could not load the RustSec database (`RUSTSEC-2026-0073` uses CVSS 4.0, which this `cargo audit` rejects). No crate in this package is in that graph |
| `csharp/Packbin.csproj` | `dotnet list package --vulnerable --include-transitive` | no vulnerable packages |
| `csharp/tests/Packbin.Tests.csproj` | same | no vulnerable packages. Test-only: xunit, the test SDK, coverlet |
| `python/pyproject.toml` | manifest | `dependencies = []` |
| Java, C++ | none | no package manifest |

No CVE applies to a library dependency of this repo.
