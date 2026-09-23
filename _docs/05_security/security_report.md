# Security Audit Report

**Date**: 2026-09-23
**Scope**: packbin
**Verdict**: PASS_WITH_WARNINGS

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 2 |

## OWASP Top 10 Assessment

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | N/A | — |
| A02 Security Misconfiguration | PASS | — |
| A03 Software Supply Chain Failures | PASS | 1 Low |
| A04 Cryptographic Failures | N/A | — |
| A05 Injection | PASS | — |
| A06 Insecure Design | PASS | — |
| A07 Authentication Failures | N/A | — |
| A08 Software or Data Integrity Failures | PASS | 1 Low |
| A09 Security Logging and Alerting Failures | N/A | — |
| A10 Mishandling of Exceptional Conditions | PASS | — |

## Findings

| # | Severity | Category | Location | Title |
|---|----------|----------|----------|-------|
| 1 | Low | A03 | `.github/workflows/test.yml`, `.github/workflows/publish.yml` | `actions/checkout@v4` is not pinned to a commit |
| 2 | Low | A08 | `.github/workflows/publish-inside.sh`, `publish-registries.sh` | Maven bundle upload has no detached signature |

## Finding Details

**F1: Actions checkout is a moving tag** (Low / A03)
- Location: `.github/workflows/test.yml`, `.github/workflows/publish.yml`
- Description: both workflows use `actions/checkout@v4`
- Impact: a rewritten tag could change what CI checks out
- Remediation: pin `actions/checkout` to a full commit SHA

**F2: Maven upload is unsigned** (Low / A08)
- Location: `.github/workflows/publish-registries.sh` `publish_java_upload`
- Description: the bundle zip is posted to `https://central.sonatype.com/api/v1/publisher/upload` with a bearer token and no `.asc`
- Impact: consumers cannot check a maintainer signature; Central may also reject the bundle
- Remediation: sign the jar and POM before upload, using a key from the CI secret store

## Dependency Vulnerabilities

| Package | CVE | Severity | Fix Version |
|---------|-----|----------|-------------|
| — | — | — | — |

`dotnet list package --vulnerable --include-transitive` reported no vulnerable packages for the C# test project. Other languages have no runtime dependencies. `cargo audit` could not load the advisory database because a RustSec file uses CVSS 4.0; `Cargo.toml` declares no dependencies.

## Recommendations

### Immediate (Critical/High)

None.

### Short-term (Medium)

None.

### Long-term (Low / Hardening)

Pin `actions/checkout` to a commit. Add a Maven signature when the Central upload is turned on for real.
