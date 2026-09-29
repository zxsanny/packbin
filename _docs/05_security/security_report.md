# Security Audit Report

**Date**: 2026-09-29
**Scope**: packbin, loop 9 session
**Verdict**: PASS_WITH_WARNINGS

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 1 |

## OWASP Top 10 Assessment

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | N/A | — |
| A02 Security Misconfiguration | PASS | — |
| A03 Software Supply Chain Failures | PASS | 1 Low |
| A04 Cryptographic Failures | PASS | — |
| A05 Injection | PASS | — |
| A06 Insecure Design | PASS | — |
| A07 Authentication Failures | N/A | — |
| A08 Software or Data Integrity Failures | PASS | — |
| A09 Security Logging and Alerting Failures | N/A | — |
| A10 Mishandling of Exceptional Conditions | PASS | — |

## Findings

| # | Severity | Category | Location | Title |
|---|----------|----------|----------|-------|
| 1 | Low | A03 | `.github/workflows/test.yml`, `.github/workflows/publish.yml` | `actions/checkout@v7` is not pinned to a commit |

### Finding Details

**F1: Actions checkout is a moving tag** (Low / A03)

- Location: `.github/workflows/test.yml`, `.github/workflows/publish.yml`
- Description: both workflows use `actions/checkout@v7`. A new v7 commit changes what CI runs.
- Impact: a compromised tag could change the checkout step on the next run.
- Remediation: pin `actions/checkout` to a full commit SHA.

The 2026-09-23 Maven finding is closed. `publish-registries.sh` writes `$file.asc`.

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

Pin `actions/checkout` to a commit SHA.
