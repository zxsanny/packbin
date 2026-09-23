# OWASP Top 10 review

**Date**: 2026-09-23
**List**: OWASP Top 10:2025 (https://owasp.org/Top10/2025/)

| Category | Status | Why |
|----------|--------|-----|
| A01 Broken Access Control | N/A | No server, account, or object id |
| A02 Security Misconfiguration | PASS | Test workflow does not contain registry token names. Publish reads GitHub secrets |
| A03 Software Supply Chain Failures | PASS | Runtime trees have no third-party packages. Test NuGet packages reported no vulnerabilities. See Low findings in the security report for unpinned Actions and image tags |
| A04 Cryptographic Failures | N/A | The library does not hash, encrypt, or store secrets |
| A05 Injection | PASS | No shell, SQL, or eval on caller input. Callers pass a field list and values in process |
| A06 Insecure Design | PASS | Callers own the field list. A short buffer returns an error and zero values |
| A07 Authentication Failures | N/A | No login |
| A08 Software or Data Integrity Failures | PASS | A tag runs the golden gate before registry writes. Maven upload is HTTPS with a bearer token and no detached signature (Low) |
| A09 Security Logging and Alerting Failures | N/A | The library does not log. Failures are return values |
| A10 Mishandling of Exceptional Conditions | PASS | Short and trailing inputs fail the call. The next pack of the position row still matches the golden hex |
