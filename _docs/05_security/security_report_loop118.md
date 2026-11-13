# Security Audit Report, loop 118 (C# sets the bit of a flags inside a flags, AZ-4251)

**Date**: 2026-11-13
**Mode**: lite escalated by T1 and T4 to the full audit, scoped to `git diff d2ba83d..HEAD -- . ':(exclude)_docs'` and the two trigger areas
**Verdict**: PASS (no finding)

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |

## Lite triggers answered
- **T1** (CI path): `ring-prepare.sh` and `publish-vcpkg.test.sh` each change one comment line (`_docs/AGENT_GOTCHAS.md` → a file under `_docs/gotchas/`); no command, permission, secret or trigger changes. The same holds for `cpp/embedded/lib.sh` (2 comment lines) and `rust/embedded/limits-m33f.txt` (6 `#` lines; the pins are unchanged).
- **T4** (manifests): the probe's `Cargo.toml` depends only on the checkout's `rust/` (path), not published; `go.mod` requires the checkout's `go/` (replace) and the indirect `golang.org/x/crypto v0.58.0` and `golang.org/x/sys v0.49.0`, the versions `go/go.mod` already pins (no new module); `Probe.csproj` has no `PackageReference` and compiles `csharp/*.cs` directly. No package manifest of a published package changed.

## Phases
- Phase 1 dependency scan: no new dependency (T4 above); the published manifests are unchanged since the loop 113 audit.
- Phase 2 SAST: the library change is one switch arm in `Walker.BitOn` (`Field.Kind.Flags => AnyChildPresent(...)`), a recursion over the scheme's own members, bounded by the scheme depth that the application writes (the loop 113 report, area 2: schemes are code, no loader). No catch, I/O, cast or allocation added. The probe runs locally, builds in `mktemp -d` folders outside the checkout, reads no input and opens no network connection except the Go probe's Docker fallback (`golang:1.27`, the image `docker-compose.test.yml` already uses, with the module cache of the run).
- Phase 3 OWASP Top 10 (2025 list as the loop 113 report uses it, not re-fetched): A01, A04, A07 N/A (no access control, crypto or authentication in the diff). A02 PASS (no config, header, port). A03 PASS (no supply-chain change, T4). A05 PASS (no input reaches a query, command or markup). A06 PASS: the fix removes a silent data loss (an inner value dropped with no error); unpack of untrusted bytes is unchanged. A08 PASS. A09 PASS (no log). A10 N/A.
- Phase 4 infrastructure: two CI scripts, comment lines only (T1); no Dockerfile, compose, workflow YAML or deploy file changed.

## Recommendations
None. Carried from loop 113: F79 (Low, the quadratic scheme walk in Java, C# and Go; queued in `backlog/hygiene.md`), F80.
