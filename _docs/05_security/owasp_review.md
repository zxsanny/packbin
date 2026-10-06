# OWASP Top 10 review

**Date**: 2026-10-06
**List**: OWASP Top 10 2025, confirmed at https://owasp.org/Top10/2025/ at the start of this audit (A01 to A10 names unchanged from earlier reviews)
**Scope**: loop 15: the round limits of C#, TypeScript, Java and Rust (unpack trust boundary), the CI pins, the read-only build containers (build, check and upload trust boundaries), the hostile cases.

## Loop 15

| Category | Status | Notes |
|----------|--------|-------|
| A01 Broken Access Control | PASS_WITH_WARNINGS | library has no request path. CI: publishing is gated only by repository write access (a `v*` tag push, by design); no `environment:` with required reviewers, no documented tag protection (F14, Low, unchanged). Job permissions unchanged and least-privilege: workflow `contents: read`, only `publish` holds `contents: write` and `id-token: write` (`publish.yml:8-9,23-25`); the called `test` workflow holds `contents: read` and no secret (`publish.yml:16-19`, `test.yml:9-10`; no `secrets: inherit`) |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | improved: the six build and gate containers mount the repo read-only (`docker-compose.publish.yml:9-10`, merged config checked: `/src` and the golden fixture read-only, `/test-results` a tmpfs, no extra volume, no `env_file`, no port, no privileged mode, no socket). Still root, default capabilities and default network, so a compromised image can read `/src/.git/config` and reach the internet (F13, Low) |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F1 **fixed**: every non-local `uses:` is a 40-hex commit with a tag comment and each SHA equals its tag (`git ls-remote`: checkout v7.0.1, setup-node v7.0.0, `NuGet/login` v1.2.0, the last one's annotated `v1` peels to the same commit). F12 **reduced**: direct tools, npm, setuptools pinned, wheels only; about 60 transitive packages still float unhashed in the credentialed job; the Maven key is visible to host pip installs in the build phase; `PYPI_TOKEN` beside OIDC; checkout credentials persist. F2, F3 unchanged |
| A04 Cryptographic Failures | PASS | session code unchanged; TLS verified on every registry call (no `-k`, no `http://`, no redirect followed); OIDC trusted publishing for npm, PyPI, crates.io; crates.io token revoked in an `always()` step (`publish.yml:58-62`) |
| A05 Injection | PASS_WITH_WARNINGS | no shell injection: `ref_name` goes through `env:`, every expansion is quoted, no `eval`; the pin lookups build `"$pkg==$pin"` from a repository file. The version string is unvalidated (F15, Low, unchanged) |
| A06 Insecure Design | PASS_WITH_WARNINGS | F10 **reduced**: the round limits are a sound design (checked before allocation, per call, scheme-owned, overflow-free), so unbounded growth with packet length is gone; but the default ceiling is 130 to 430 MiB per call, `bits` and `packed` stay linear at 36 to 257 times the packet, and `README.md:1046` states a stronger bound than holds. F11 fixed. Pipeline design: build then check then upload, required before optional, fail-closed registry queries |
| A07 Authentication Failures | N/A | no accounts. Registry auth: OIDC where available |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F13 **reduced**: a container can no longer change scripts or other targets' artifacts; what it writes into its own folder is still not validated for symlinks, and for Rust the uploaded tree (`stage/`) is not the checked `.crate`. F16 unchanged. F5, F8 fixes verified in loop 13 and unchanged |
| A09 Security Logging and Alerting Failures | N/A | libraries do not log. Pipeline logs carry no secret; `already published` and `skipping optional target` stay visible |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | unpack returns an error value for every limit refusal in all four packages and no new exception is reachable from a packet; the registry queries stay fail-closed. F17 (Low): a typed C# `Unpack` throws `InvalidCastException` for any packet that holds a round (`Packbin.cs:62-67`), pre-existing and documented |

### Who can publish what

Unchanged from loop 14: a `v*` tag by anyone with write access starts `publish`, secrets are repository-level, `needs: test` only proves the same commit's tests pass (F14). The new test scripts and `docker-compose.publish.yml` add neither a write path to a registry nor a credential to a container: containers get `SRC_ROOT`, `PACKBIN_VERSION`, `PACKBIN_OUT`, `PACKBIN_HOST_UID`, `PACKBIN_HOST_GID` and the compose constants only.

## Earlier loops (condensed)

- Loop 10/11/13/14 A01 to A10: no access control (library); F4 to F9 fixed; F10, F11 opened in loop 13; F12 to F16 opened in loop 14; A03 PASS_WITH_WARNINGS from F1 to F3. Full tables are in git history (`git show 43af2f6:_docs/05_security/owasp_review.md`).
