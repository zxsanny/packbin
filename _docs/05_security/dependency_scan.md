# Dependency scan

**Date**: 2026-10-06
**Scope**: loop 14 (`git diff c6c389c..HEAD`, HEAD 43af2f6): publish pipeline, Java API-26 check. Earlier loops condensed below.

## Loop 14

| Manifest / source | Tool | Result |
|-------------------|------|--------|
| `typescript/package.json`, `package-lock.json` | `npm audit` (registry reachable) | 0 vulnerabilities (`@noble/hashes` 2.4.0, dev `typescript`). Unchanged since loop 13 |
| `rust/Cargo.toml`, `Cargo.lock` | `cargo audit` | could not run: the installed `cargo-audit` fails on a CVSS 4.0 advisory (`unsupported CVSS version: 4.0`), as in loop 13. `Cargo.lock` lists only the crate itself; nothing to audit |
| `python/pyproject.toml` | manifest read | `dependencies = []`; build backend `setuptools>=61` (line 12), not pinned: the container build fetches the newest release (see F13). OSV lists 10 advisories for setuptools, all fixed in releases at or below 83.0.0 (`GHSA-h35f-9h28-mq5c` is the newest); none affects a current release by the registry data read |
| `csharp/Packbin.csproj`, `java/`, `cpp/` | manifest read | no package references; `dotnet pack` restores nothing |
| `.github/workflows/publish-upload.sh:133-135`, `publish-embedded.sh:128,134`, `publish-inside.sh:52` | registry metadata (PyPI JSON, OSV) | `twine` 7.0.0, `platformio` 6.2.0, `idf-component-manager` 3.1.2, `build`: **0 advisories** in OSV. None is pinned and none has a hash; `platformio` and `idf-component-manager` pull 12 to 15 unpinned transitive packages (`requests`, `pydantic`, `starlette`, `uvicorn`, `bottle`, ...). Not a vulnerability today; the exposure is F12 |
| `java/api-check.sh:15-17` (new in loop 14) | download and hash | the three artifacts pinned by SHA-256 were fetched from Maven Central and hashed: `animal-sniffer-1.28.jar` `3a4431...9443`, `asm-9.10.1.jar` `ed825d...fcb`, `android-api-level-26-8.0.0_r2.signature` `0a6681...5ddd36` all equal the pinned values, and their SHA-1 equal Central's published `.sha1` files. Both jars come from the official groupIds (`org.codehaus.mojo`, `org.ow2.asm`). No advisory for either version found |
| GitHub Actions | manifest read | `actions/checkout@v7`, `actions/setup-node@v7`, `NuGet/login@v1`: moving tags (F1, F12) |
| Container images (`docker-compose.test.yml`) | manifest read | tags, not digests (F3) |

No known-vulnerable dependency. No Critical or High.

## Earlier loops (condensed)

- Loop 10: C++ core has no dependencies; `cpp/embedded/examples.sh` downloads `arduino-cli` without a checksum (F2).
- Loop 11: `typescript` (`@noble/hashes` 2.4.0), `rust`, `python`, `csharp`, `java` unchanged; no vulnerable package.
- Loop 13: `npm audit` 0; `dotnet list package --vulnerable --include-transitive` for `csharp/tests/Packbin.Tests.csproj` (xunit 2.9.3, Test.Sdk 17.14.1, coverlet 6.0.4, runner 3.1.4) and the `Handoff.csproj` driver: none; `cargo audit` failed on CVSS 4.0.
