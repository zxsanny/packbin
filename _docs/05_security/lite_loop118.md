# Security lite — loop 118 (AZ-4251)

diff: `git diff d2ba83d..HEAD -- . ':(exclude)_docs'` (32 files, +2,093 / -11: 1 library line, 1 test file, the new probe of 30 files, 4 comment-only path edits)

| # | trigger | hit |
|---|---------|-----|
| T1 | sensitive path | yes: `.github/workflows/ring-prepare.sh`, `.github/workflows/publish-vcpkg.test.sh` (one comment line each, the gotchas path) |
| T2 | sensitive content | no (grep of added lines: no token, secret, ssh, sudo, eval, process start, URL) |
| T3 | size | no: complexity 3; 1 changed library line; the probe is 30 new files under `scripts/probes/` |
| T4 | dependencies | yes: new probe manifests `scripts/probes/flags-in-flags/{rust/Cargo.toml, go/go.mod, csharp/Probe.csproj}` |
| T5 | carried finding touched | no (F79 names `SchemeOrder.java`, `RoundScopes.cs`, `counted.go`; F80 the ECC test) |
| T6 | stale audit | no (last full report loop 113, 2026-11-12) |
| T7 | lite concern | no |

Checks on changed lines: injection, output encoding, authn/authz, secrets and logs, input limits, outbound, edge config: nothing applies (a library presence rule, unit tests, a local probe).

verdict: ESCALATE (T1, T4) → `security_report_loop118.md`
