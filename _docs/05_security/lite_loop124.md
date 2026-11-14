# Security lite — loop 124 (AZ-4288)

diff: `git diff 1c24621..HEAD -- . ':(exclude)_docs'` (8 files: `run-suite.sh`, three new sourced helper files, `run-suite.test.sh`, a new sourced `run-suite-cpp.test.sh`, `report-row.test.sh`)

| # | trigger | hit |
|---|---------|-----|
| T1 | sensitive path | yes: `.github/workflows/` shell files |
| T2 | sensitive content | no new content: the moved lines are identical to the removed ones (checked by diff); the only new lines are file headers, `.` source lines and one wider `grep` file list |
| T3 | size | no (2 points; about 130 lines moved, about 20 new) |
| T4 | dependencies | no |
| T5 | carried finding touched | no open finding |
| T6 | stale audit | no (loop 123) |
| T7 | lite concern | no |
| T8 | revisit row | no |

verdict: ESCALATE (T1) → scoped audit below, answered in this file because the diff is a word-for-word move.

## Scoped audit (T1)
The sourced files are read from `$(dirname "${BASH_SOURCE[0]}")`, the same directory as `run-suite.sh`, as `run-suite-dart.sh` has been since AZ-4145: no path comes from input or the environment. No command, origin, privilege, secret or network call is added or changed. The registry-name guard (`report-row.test.sh`) now covers the moved code too. PASS, no finding.
