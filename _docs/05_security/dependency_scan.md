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
