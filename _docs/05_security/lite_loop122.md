# Security lite — loop 122 (AZ-4277, AZ-4278)

diff: `git diff 8dd3dba..HEAD -- . ':(exclude)_docs'` (8 files, 97 changed lines)

| # | trigger | hit |
|---|---------|-----|
| T1 | sensitive path | yes: `.github/workflows/run-suite.sh`, `run-suite.test.sh`, `tool-pins.txt`, `publish-pins.test.sh` (CI files), `docker-compose.test.yml` |
| T2 | sensitive content | no real hit: no secret, header, network listener or process start from input; the new outbound fetch is the apt install below |
| T3 | size | no (8 files, 4 points) |
| T4 | dependencies | yes: a new tool pin (`clang==19`, Debian packages `clang-19`, `libclang-rt-19-dev` installed in the test container) |
| T5 | carried finding touched | no (open: none; L1 of loop 121 is the ESP core, not touched) |
| T6 | stale audit | no (full audit loop 121, 2026-11-13) |
| T7 | lite concern | no |
| T8 | revisit row | no open `revisit-security` row |

verdict: ESCALATE (T1, T4) → `security_report_loop122.md`
