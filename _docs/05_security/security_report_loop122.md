# Security Audit Report, loop 122 (hygiene: Dart cost test, C++ sanitizer in CI; AZ-4277, AZ-4278)

**Date**: 2026-11-13
**Mode**: lite escalated by T1, T4 to the full audit, scoped to `git diff 8dd3dba..HEAD -- . ':(exclude)_docs'` and the CI test path it changes
**Verdict**: PASS (no Critical, High or Medium; 1 Low)

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 1 |

## Lite triggers answered
- **T1/T4** (CI scripts, compose, tool pin): the compose `cpp` service gains a static environment value `PACKBIN_CPP_SANITIZER: "1"`; no port, volume, network mode or privilege changes. `run-suite.sh cpp` then runs, inside the throwaway `gcc:16` test container as its root user (as every suite container), `apt-get -o Acquire::Retries=3 update` and `apt-get install --no-install-recommends clang-<major> libclang-rt-<major>-dev` from the image's own Debian sources: apt verifies the signed repository metadata and package hashes, so no unsigned code is installed and no new origin is added beyond Debian's mirror. `<major>` comes from `tool-pins.txt` through `tool-pin.sh`, which accepts only `digits(.digits)*`, so no input reaches the package names or the make line; every expansion is quoted. The sanitizer run has a 10-minute `timeout`. No secret reaches the container (the suites job passes none). `publish-pins.test.sh` only adds `clang` to its allowed-name list. **L1 (Low)**: the pin fixes the clang major only; the Debian package revision floats with the image's mirror, and the `gcc:16` tag itself floats, so a rebuild of the image on a later Debian could drop `clang-19` (a loud CI failure naming the package, not a silent change). Remediation: none now; bump the pin when the base moves (hygiene entry).

## Phases
- Phase 1 dependency scan: no package manifest of a published library changed; the only new dependency is the test-time compiler above (not shipped).
- Phase 2 SAST: library code unchanged. `cpp/Makefile` adds `-fbracket-depth=512` to the sanitizer flags only. The C++ test change guards `memcpy`/`memcmp` against an empty vector's null pointer (removes undefined behaviour in a test). The Dart test change times three builds instead of one.
- Phase 3 OWASP Top 10 (2025 list as the loop 118 report uses it, not re-fetched): A01, A04, A07, A10 N/A. A02 PASS (no service config). A03 PASS (signed Debian packages, a pinned major; L1). A05 PASS (no input reaches a command; the pin is validated). A06 PASS. A08 PASS (apt signature checks). A09 PASS.
- Phase 4 infrastructure: compose gains one static environment key; no workflow YAML changed; the CI job count stays 20.

## Recommendations
Long term (Low): L1 above.
