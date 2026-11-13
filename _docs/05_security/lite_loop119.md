# Security lite — loop 119 (AZ-4253)

diff: `git diff 4196c0e..HEAD -- . ':(exclude)_docs'` (6 files, +228 / -1: 2 library files, 3 test files, 1 README line)

| # | trigger | hit |
|---|---------|-----|
| T1 | sensitive path | no |
| T2 | sensitive content | no (0 matches in added lines) |
| T3 | size | no: 3 points, 2 non-test source files, about 80 non-test lines |
| T4 | dependencies | no |
| T5 | carried finding touched | no (F79 names `SchemeOrder.java`, not changed) |
| T6 | stale audit | no (full audit loop 118, 2026-11-13) |
| T7 | lite concern | no |

Checks on changed lines: injection, output encoding, authn/authz, secrets, input limits, outbound, edge config: nothing applies. The new check runs only at scheme construction, on the application's own accessors and factory (schemes are code: README "Untrusted input"); unpack of untrusted bytes is unchanged. The `catch (RuntimeException)` in `RowClassCheck.call` swallows only a failure of the application's own accessor on an empty child, documented, and pack reports it where it happens.

Low: the build now calls the application's factory and each member's getter and setter once (D13, accepted-risk in the spec): an accessor with side effects runs once more. Remediation: none; stated in the README bullet.

verdict: CLEAN
