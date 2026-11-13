# Security lite — loop 123 (AZ-4279, AZ-4280)

diff: `git diff b41badd..HEAD -- . ':(exclude)_docs'` (6 files: two C++ headers, a host test, the Makefile flag line, `run-suite.sh`, `run-suite.test.sh`)

| # | trigger | hit |
|---|---------|-----|
| T1 | sensitive path | yes: `.github/workflows/run-suite.sh`, `run-suite.test.sh` (CI files) |
| T2 | sensitive content | no: no secret, header, listener or process start; the added line prints `/etc/debian_version` |
| T3 | size | no (6 files, 3 points) |
| T4 | dependencies | no |
| T5 | carried finding touched | yes: L1 of loop 122 (clang-19 tied to the floating gcc:16 base): `run-suite.sh` |
| T6 | stale audit | no (loop 122) |
| T7 | lite concern | no |
| T8 | revisit row | no open row |

verdict: ESCALATE (T1, T5) → `security_report_loop123.md`
