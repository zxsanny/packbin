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
