# Security lite — loop 121 (AZ-4257 to AZ-4261)

diff: `git diff 4c1b51f..HEAD -- . ':(exclude)_docs'` (26 changed + 8 new files)

| # | trigger | hit |
|---|---------|-----|
| T1 | sensitive path | yes: `.github/workflows/tool-pins.txt`, `.github/workflows/publish-pins.test.sh` (CI files) |
| T2 | sensitive content | no real hit: the word `hash` in `LinkedHashMap` / `HashMap` and `token` in existing comments only; no secret, header, process start or network call added except the ESP core install below |
| T3 | size | yes: 34 files, about 14 points |
| T4 | dependencies | yes: a new tool pin (`arduino-esp32==3.3.12`) |
| T5 | carried finding touched | yes: F79 (`SchemeOrder.java`, `RoundScopes.cs`, `counted.go`) — fixed by this loop |
| T6 | stale audit | no (full audit loop 118, 2026-11-13) |
| T7 | lite concern | no |

verdict: ESCALATE (T1, T3, T4, T5) → `security_report_loop121.md`

Added after step 11: `88df315` adds two `# shellcheck disable=SC2016` comment lines to `cpp/embedded/lib.test.sh`; no trigger is new (comment lines in a test script); the three stages that path selects (`cpp`, `scaffold`, `cpp-embedded-arm`) were re-run and passed.
