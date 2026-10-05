# Security Audit Report

**Date**: 2026-10-05
**Scope**: packbin, loop 10: the C++ core for microcontrollers, the hostile-packet vectors, the embedded CI
**Verdict**: PASS_WITH_WARNINGS

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 open (1 found and fixed in this loop) |
| Medium | 0 |
| Low | 3 |

One High finding (F0) was found by this audit and fixed in the same loop with a regression vector that runs on the 32-bit targets. Verdict logic counts open findings.

## OWASP Top 10 Assessment

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | N/A | — |
| A02 Security Misconfiguration | PASS | — |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | 3 Low |
| A04 Cryptographic Failures | PASS | — |
| A05 Injection | PASS | — |
| A06 Insecure Design | PASS | — |
| A07 Authentication Failures | N/A | — |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F2 |
| A09 Security Logging and Alerting Failures | N/A | — |
| A10 Mishandling of Exceptional Conditions | PASS (F0 fixed) | — |

## Findings

| # | Severity | Category | Location | Title |
|---|----------|----------|----------|-------|
| 0 | High (fixed) | A10 / A06 | `cpp/src/core/unpack.cpp` `unpack_small` | A 64-bit count wraps to a small `size_t` on 32-bit targets, and the unpack loop reads and writes past its buffers |
| 1 | Low | A03 | `.github/workflows/test.yml`, `.github/workflows/publish.yml` | `actions/checkout@v7` is not pinned to a commit (open since 2026-09-29) |
| 2 | Low | A03 / A08 | `cpp/embedded/examples.sh:25` | `arduino-cli` tarball is downloaded and run without a checksum |
| 3 | Low | A03 | `cpp/embedded/Dockerfile:4`, `docker-compose.test.yml` | `ubuntu:24.04` and `espressif/idf:v5.3.2` are pinned by tag, not by digest |

### Finding Details

**F0: Truncated count in `bits` / `packed` unpack on 32-bit targets** (High, fixed / A10, A06)
- Location: `cpp/src/core/unpack.cpp`, `unpack_small` (before batch 6)
- Description: the count comes from an earlier field and is held as `int64`. Where `size_t` is 32 bits (every microcontroller target), the byte length and the capacity check used `static_cast<size_t>(count)`, which drops the high bits, while the loop that stores the values ran to the full `int64` count. A `u64` count source of `0x100000004` with a one-byte `bits` body passed both checks as the value 4, and the loop then read past the packet and wrote past the `Array`.
- Impact: a crafted packet from the radio could corrupt memory next to the row on a Cortex-M or ESP32 target.
- Evidence: the new vector `wide_count_is_not_truncated` (`counted_tests.cpp`) crashed the Cortex-M3 QEMU run (vector runner exit 120, vectors run 0) before the fix and passes after it (214 of 214); s390x and the 64-bit host passed both times. The 20 M-packet fuzz ran on a 64-bit host, which cannot show this.
- Remediation (done): counts are clamped to just under `SIZE_MAX` before any narrowing (`clamp_count`), the byte length is computed in 64 bits, and the capacity check compares in `int64`. The same clamp now protects `sized` lengths and `times` counts, which wrapped to a smaller value instead of failing.

**F1: Actions checkout is a moving tag** (Low / A03)
- Location: `.github/workflows/test.yml`, `.github/workflows/publish.yml`
- Description: both workflows use `actions/checkout@v7`. A new v7 commit changes what CI runs.
- Impact: a compromised tag could change the checkout step on the next run.
- Remediation: pin `actions/checkout` to a full commit SHA.

**F2: Unverified tool download in the example job** (Low / A03, A08)
- Location: `cpp/embedded/examples.sh:25`
- Description: the job fetches the `arduino-cli` 1.1.1 tarball over HTTPS and runs it. The version is fixed, but the archive is not compared with a known SHA-256.
- Impact: a replaced release asset would run in a CI job that has no publish secrets (the `embedded` job holds none).
- Remediation: store the SHA-256 of each archive in the script and check it with `sha256sum -c` before `tar`.

**F3: Base images pinned by tag** (Low / A03)
- Location: `cpp/embedded/Dockerfile:4`; `espressif/idf:v5.3.2` in `docker-compose.test.yml`
- Description: a tag can be moved. The images only build and test; they hold no secrets.
- Impact: a changed image could alter a CI result.
- Remediation: pin both images by digest when the next toolchain bump is done.

## Evidence for the C++ core

The core parses untrusted radio packets into caller storage. Every read is checked against the packet length before use, and every write against the buffer capacity (`core.hpp:119,129`; `values.cpp:145`). 20 000 000 mutated packets of the all-kinds scheme (every field kind) were unpacked from exact-size heap copies under AddressSanitizer and UndefinedBehaviorSanitizer with recovery off: 0 reports. The 17 shared hostile cases run on the host with a 1 s watchdog and canary bytes: 0 hangs, 0 writes outside the row. The batch review found one slow path (an empty-body `times` with a huge count) and one stack-margin risk; both were fixed in batch 5. The audit then found F0, which only a 32-bit run exposes; the 64-bit fuzz could not.

The session has no authentication tag. That is the accepted session criterion, not a new finding.

## Dependency Vulnerabilities

| Package | CVE | Severity | Fix Version |
|---------|-----|----------|-------------|
| none | — | — | — |

## Recommendations

### Immediate (Critical/High)

None.

### Short-term (Medium)

None.

### Long-term (Low / Hardening)

Pin `actions/checkout` to a commit SHA (F1). Check the `arduino-cli` archive against a stored SHA-256 (F2). Pin the two embedded images by digest (F3).
