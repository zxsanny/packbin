# Static analysis

**Date**: 2026-09-29
**Scope**: the six packages and `.github/workflows`

| Check | Result |
|-------|--------|
| Command or SQL injection | none in library source. `Process.Start` is in `csharp/tests/SchemeTests.cs` and starts the compile-fail fixture |
| Hardcoded registry tokens | none. `publish.yml` uses `secrets.*`. `publish-gate.test.sh` uses the literal `cio-secret` only as a stub curl response |
| Nonce | `python/src/packbin/_session.py` draws 16 bytes with `secrets.token_bytes` |
| Session pad | HKDF-SHA256, info `packbin`, ChaCha20. The contract says there is no tag. A flipped bit is out of scope in the session acceptance criteria |
| Deserialization of an untrusted object graph | unpack reads the caller's scheme. It does not pickle |
| Secrets in logs | the library does not log |

No new static finding. The unpinned Actions checkout stays the one Low item in the security report.
