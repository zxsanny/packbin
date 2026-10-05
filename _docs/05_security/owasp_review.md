# OWASP Top 10 review

**Date**: 2026-10-05
**List**: OWASP Top 10 2025, as in the 2026-09-29 review

| Category | Status | Notes |
|----------|--------|-------|
| A01 Broken Access Control | N/A | library. No request path |
| A02 Security Misconfiguration | PASS | the embedded images publish no port; the core has no configuration |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F1 (moving `actions/checkout` tag, open), F2 (`arduino-cli` download without a checksum). The core has no dependencies |
| A04 Cryptographic Failures | PASS | the session code is unchanged since the loop 9 review; no new primitive |
| A05 Injection | PASS | no query, command or markup built from input |
| A06 Insecure Design | PASS | decode paths return error values; storage is caller-owned with fixed maxima; the zero-progress and per-scope flag-byte rules close the two loop 10 logic faults that a crafted packet could reach |
| A07 Authentication Failures | N/A | no accounts |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F2. The session has no authentication tag; that is the accepted session criterion, not a new finding |
| A09 Security Logging and Alerting Failures | N/A | the core does not log |
| A10 Mishandling of Exceptional Conditions | PASS | no exceptions; every failure is a `Result`; 20 M fuzzed packets produced no crash or sanitizer report on a 64-bit host. F0 (32-bit count truncation, High) was found on the Cortex-M3 run and fixed |
